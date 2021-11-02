#!/usr/bin/python3

import os
from tempfile import mkdtemp
from multiprocessing import Lock
from random import randrange
from pathlib import Path
from hashlib import sha256
from multiprocessing import Process

from hcp import HcpSwtpmsvc, HcpAttestclient, HcpNetwork
from enroll_api import enroll_add, enroll_delete, enroll_query, enroll_find

# The enroll_api functions take an 'args' object that contain inputs parsed
# from the command-line (via 'argparse'). We want to use the same functions
# programmatically, so we use an empty class to emulate 'args' and we add
# members to it dynamically. (I.e. a Dict won't suffice.)
class HcpArgs:
	pass

# This object represents a bank of swtpm instances that we use to test
# enrollment and attestation endpoints. It is backed onto the filesystem and if
# a 'path' argument is provided to the constructor it will be persistent from
# one usage to the next. (Otherwise if 'path' is None, a new bank is created
# each time using a path created by tempfile.mkdtemp().)
class HcpSwtpmBank:

	def __init__(self, *,
		     num=0,
		     path=None,
		     enrollAPI = 'http://localhost:5000',
		     attestAPI = 'http://localhost:8080',
		     verifier = None,
		     net = None):
		self.path = path
		self.enrollAPI = enrollAPI
		self.attestAPI = attestAPI
		self.verifier = verifier
		self.net = net
		self.entries = []
		if not self.path:
			self.path = mkdtemp()
		if not os.path.isdir(self.path):
			os.mkdir(self.path)
		self.numFile = self.path + '/num'
		if os.path.isfile(self.numFile):
			print('Latching to existing bank', end=' ')
			self.num = int(open(self.numFile, 'r').read())
			print(f'of size {self.num}')
			if self.num < num:
				print(f'Expanding bank from {self.num} to {num}')
				self.num = num
				open(self.numFile, 'w').write(f'{self.num}')
			elif self.num > num and num > 0:
				print(f'Error, real bank size {self.num} bigger than {num}')
				raise Exception("Bank size bigger than expected")
		else:
			print('Initializing new bank')
			self.num = num
			open(self.numFile, 'w').write(f'{self.num}')
		if self.num == 0:
			raise Exception('Bank size must be non-zero')
		for n in range(self.num):
			entry = {
				'path': self.path + '/t{num}'.format(num = n),
				'index': n,
				'lock': Lock()
				}
			entry['tpm'] = None
			entry['tpmEKpub'] = entry['path'] + '/state/tpm/ek.pub'
			entry['tpmEKpem'] = entry['path'] + '/state/tpm/ek.pem'
			entry['enrolled'] = Path(entry['path'] + '/enrolled')
			entry['hostname'] = None
			entry['ekpubhash'] = None
			self.entries.append(entry)

	def Initialize(self):
		# If we Delete and then Initialize, the directory needs to be recreated.
		if not os.path.isdir(self.path):
			os.mkdir(self.path)
			open(self.numFile, 'w').write(f'{self.num}')
		# So here's the idea. We want to enroll each TPM against a
		# unique hostname, and then the first time we try to unenroll
		# that TPM, we'll call the 'find' API using the hostname to get
		# back the TPM's ekpubhash.  This helps test the 'find' API,
		# for one thing, but also means we are independent of how the
		# enrollment and attestation services hash and index the TPMs
		# (which, as it happens, is changing from being a sha256 hash
		# of the TPM2B_PUBLIC-format ek.pub to a sha256 hash of the
		# PEM-format ek.pem). To keep our TPM->hostname mapping
		# distinct, we hash _both_ forms of the EK.
		enrollargs = HcpArgs()
		enrollargs.api = self.enrollAPI
		for entry in self.entries:
			if not entry['tpm']:
				entry['tpm'] = HcpSwtpmsvc(net = self.net,
						path=entry['path'],
						contName=f"testswtpm{entry['index']}",
						hostName=f"testswtpm{entry['index']}")
				entry['tpm'].Initialize()
				grind = sha256()
				grind.update(open(entry['tpmEKpub'], 'rb').read())
				grind.update(open(entry['tpmEKpem'], 'rb').read())
				digest = grind.digest()
				entry['hostname'] = digest[:4].hex() + '.nothing.xyz'
				enrollargs.hostname_suffix = entry['hostname']
				result, jr = enroll_find(enrollargs)
				if not result:
					raise Exception('Enrollment \'find\' failed')
				num = len(jr['ekpubhashes'])
				if num > 0:
					if (num > 1):
						raise Exception('Multiple TPMs per host-name?!')
					entry['ekpubhash'] = jr['ekpubhashes'].pop()
					entry['enrolled'].touch()
					desc = 'enrolled'
				else:
					if entry['enrolled'].is_file():
						entry['enrolled'].unlink()
					desc = 'unenrolled'
				if entry['tpm'].Running():
					desc += ', running'
				else:
					desc += ', not running'
				print('Initialized {num} at {path}, {desc}'.format(
					num = entry['index'],
					path = entry['path'],
					desc = desc))

	def Delete(self):
		for entry in self.entries:
			print('Deleting {num} at {path}'.format(
				num = entry['index'],
				path = entry['path']))
			if not entry['tpm']:
				entry['tpm'] = HcpSwtpmsvc(path=entry['path'])
			if entry['enrolled'].is_file():
				entry['enrolled'].unlink()
			entry['tpm'].Delete()
			entry['tpm'] = None
		Path(self.numFile).unlink()
		os.rmdir(self.path)

	def AllIn(self):
		enrollargs = HcpArgs()
		enrollargs.api = self.enrollAPI
		for entry in self.entries:
			if not entry['enrolled'].is_file():
				print('{idx} enrolling'.format(idx=entry['index']))
				enrollargs.ekpub = entry['tpmEKpem']
				enrollargs.hostname = entry['hostname']
				result, jr = enroll_add(enrollargs)
				if not result:
					raise Exception('Enrollment \'add\' failed')
				entry['enrolled'].touch()
			else:
				print('{idx} already enrolled'.format(idx=entry['index']))

	def AllOut(self):
		enrollargs = HcpArgs()
		enrollargs.api = self.enrollAPI
		for entry in self.entries:
			if entry['enrolled'].is_file():
				print('{idx} unenrolling'.format(idx=entry['index']))
				enrollargs.ekpubhash = entry['ekpubhash']
				result, jr = enroll_delete(enrollargs)
				if not result:
					raise Exception('Enrollment \'delete\' failed')
				entry['enrolled'].unlink()
			else:
				print('{idx} already unenrolled'.format(idx=entry['index']))

	def AllStart(self):
		for entry in self.entries:
			if not entry['tpm'].Running():
				print('{idx} running'.format(idx=entry['index']))
				entry['tpm'].Start()
			else:
				print('{idx} already running'.format(idx=entry['index']))

	def AllStop(self):
		for entry in self.entries:
			if entry['tpm'].Running():
				print('{idx} stopping'.format(idx=entry['index']))
				entry['tpm'].Stop()
			else:
				print('{idx} already stopped'.format(idx=entry['index']))

	def Soak(self, loop, threads, pcattest):
		children = []
		for _ in range(threads):
			p = Process(target=self.Soak_thread, args=(loop,pcattest,))
			p.start()
			children.append(p)
		while len(children):
			p = children.pop()
			p.join()

	def Soak_thread(self, loop, pcattest):
		for _ in range(loop):
			self.Soak_iteration(pcattest)

	def Soak_iteration(self, pcattest):
		enrollargs = HcpArgs()
		enrollargs.api = self.enrollAPI
		res = False
		while not res:
			idx = randrange(0, self.num)
			entry = self.entries[idx]
			res = entry['lock'].acquire(block = False)
		if entry['enrolled'].is_file():
			# It's enrolled. Choose whether to attest or unenroll it.
			if pcattest > randrange(0, 100):
				# attest
				print('{idx} enrolled, attesting.'.format(idx=idx), end=' ')
				self.Soak_locked_attest(entry)
			else:
				# unenroll
				print('{idx} enrolled, unenrolling.'.format(idx=idx), end=' ')
				self.Soak_locked_unenroll(enrollargs, entry)
		else:
			# It's not enrolled. Enroll it.
			print('{idx} unenrolled, enrolling.'.format(idx=idx), end=' ')
			self.Soak_locked_enroll(enrollargs, entry)
		print('OK')
		entry['lock'].release()

	def Soak_locked_enroll(self, enrollargs, entry):
		pubOrPem = randrange(0, 2)
		if pubOrPem == 0:
			print('TPM2B_PUBLIC.', end=' ')
			enrollargs.ekpub = entry['tpmEKpub']
		else:
			print('PEM.', end=' ')
			enrollargs.ekpub = entry['tpmEKpem']
		enrollargs.hostname = entry['hostname']
		result, jr = enroll_add(enrollargs)
		if not result:
			raise Exception(f"Enrollment \'add\' failed index {entry['index']}")
		entry['enrolled'].touch()

	def Soak_locked_unenroll(self, enrollargs, entry):
		if not entry['ekpubhash']:
			# Lazy initialize the ekpubhash value, using 'find'
			enrollargs.hostname_suffix = entry['hostname']
			result, jr = enroll_find(enrollargs)
			if not result:
				raise Exception('Enrollment \'find\' failed')
			num = len(jr['ekpubhashes'])
			if num != 1:
				raise Exception(f'Enrollment \'find\' return {num} hashes')
			entry['ekpubhash'] = jr['ekpubhashes'].pop()
			print('lazy-init ekpubhash={ekph}.'.format(
				ekph = entry['ekpubhash']), end=' ')
		enrollargs.ekpubhash = entry['ekpubhash']
		result, jr = enroll_delete(enrollargs)
		if not result:
			raise Exception('Enrollment \'delete\' failed')
		entry['enrolled'].unlink()

	def Soak_locked_attest(self, entry):
		client = HcpAttestclient(net = self.net,
				attestURL = self.attestAPI,
				tpm2TCTI = f"swtpm:host=testswtpm{entry['index']},port=9876",
				contName = f"testclient{entry['index']}",
				hostName = f"testclient{entry['index']}",
				assetSigner = self.verifier)
		client.Run()

if __name__ == '__main__':

	import argparse
	import sys

	def cmd_test_common(args):
		if not args.path:
			print("Error, no path provided (--path)")
			sys.exit(-1)
		args.network = HcpNetwork(prefix = args.prefix, suffix = args.suffix)
		args.bank = HcpSwtpmBank(net = args.network,
					 path = args.path,
					 num = args.num,
					 enrollAPI = args.enrollapi,
					 attestAPI = args.attestapi,
					 verifier = args.verifier)
	def cmd_test_create(args):
		cmd_test_common(args)
		args.bank.Initialize()

	def cmd_test_delete(args):
		cmd_test_common(args)
		args.bank.Delete()

	def cmd_test_allin(args):
		cmd_test_common(args)
		args.bank.Initialize()
		args.bank.AllIn()

	def cmd_test_allout(args):
		cmd_test_common(args)
		args.bank.Initialize()
		args.bank.AllOut()

	def cmd_test_allstart(args):
		cmd_test_common(args)
		args.bank.Initialize()
		args.bank.AllStart()

	def cmd_test_allstop(args):
		cmd_test_common(args)
		args.bank.Initialize()
		args.bank.AllStop()

	def cmd_test_soak(args):
		cmd_test_common(args)
		args.bank.Initialize()
		if args.loop < 1:
			print(f"Error, illegal loop value ({args.loop})")
			sys.exit(-1)
		if args.threads < 1:
			print(f"Error, illegal threads value ({args.threads})")
			sys.exit(-1)
		args.bank.Soak(args.loop, args.threads, args.pcattest)

	fc = argparse.RawDescriptionHelpFormatter

	# Wrapper 'test' command
	test_desc = 'Toolkit for testing HCP services and functions'
	test_epilog = """
This tool manages and uses a corpus of TPM EK (Endorsement Keys).

* If the path for the corpus is not supplied on the command line (via
  '--path'), it will fallback to using the 'HCP_EKBANK_PATH'
  environment variable.

* If the number of entries to use in the corpus is not supplied (via
  '--num') it is presumed that the bank already exists.

* If the namespace prefix is not supplied (via '--prefix'), it will
  fallback to using the 'HCP_PREFIX' environment variable. Similarly,
  the namespace suffix is supplied via '--suffix' or the 'HCP_SUFFIX'
  environment variable. This allows software TPMs and attestation
  clients to launch on the same network as the Attestation Service.
  The network name is assumed to be "<prefix>network".

* If the base URL for the Enrollment Service's management API is not
  supplied on the command line (via '--enrollapi'), it will fallback
  to using the 'HCP_ENROLLSVC_API_URL' environment variable.

* If the URL for the Attestation Service is not supplied on the
  command line (via '--attestapi'), it will fallback to using the
  'HCP_ATTESTSVC_API_URL' environment variable.

* If the trust anchor for asset-signing is not supplied on the command
  line (via '--verifier'), it will fallback to using the
  'HCP_VERIFIER' environment variable.

To see subcommand-specific help, pass '-h' to the subcommand.
	"""
	test_help_path = 'path for the corpus'
	test_help_num = 'number of instances/EKpubs to support'
	test_help_prefix = 'Namespace prefix for Docker network and other objects'
	test_help_suffix = 'Namespace suffix for Docker network and other objects'
	test_help_enrollapi = 'base URL for the Enrollment Service management interface'
	test_help_attestapi = 'URL for the Attestation Service interface'
	test_help_verifier = 'Path to trust anchor for asset-signing'
	parser = argparse.ArgumentParser(description = test_desc,
					 epilog = test_epilog,
					 formatter_class = fc)
	default_prefix = os.environ.get('HCP_PREFIX')
	if not default_prefix:
		default_prefix = 'safeboot_hcp_'
	default_suffix = os.environ.get('HCP_SUFFIX')
	if not default_suffix:
		default_suffix = 'devel'
	parser.add_argument('--path',
			   default = os.environ.get('HCP_EKBANK_PATH'),
			   help = test_help_path)
	parser.add_argument('--num',
			   type = int,
			   default = 0,
			   help = test_help_num)
	parser.add_argument('--prefix', metavar='<PREFIX>',
			    default = default_prefix,
			    help = test_help_prefix)
	parser.add_argument('--suffix', metavar='<SUFFIX>',
			    default = default_suffix,
			    help = test_help_suffix)
	parser.add_argument('--enrollapi', metavar='<URL>',
			    default = os.environ.get('HCP_ENROLLSVC_API_URL'),
			    help = test_help_enrollapi)
	parser.add_argument('--attestapi', metavar='<URL>',
			    default = os.environ.get('HCP_ATTESTSVC_API_URL'),
			    help = test_help_attestapi)
	parser.add_argument('--verifier', metavar='<PATH>',
			    default = os.environ.get('HCP_VERIFIER'),
			    help = test_help_verifier)
	subparsers = parser.add_subparsers()

	# ::create
	test_create_help = 'Creates/updates a bank of sTPM instances'
	test_create_epilog = ''
	parser_test_create = subparsers.add_parser('create',
						help = test_create_help,
						epilog = test_create_epilog)
	parser_test_create.set_defaults(func = cmd_test_create)

	# ::delete
	test_delete_help = 'Deletes a bank of sTPM instances'
	test_delete_epilog = ''
	parser_test_delete = subparsers.add_parser('delete',
						help = test_delete_help,
						epilog = test_delete_epilog)
	parser_test_delete.set_defaults(func = cmd_test_delete)

	# ::allin
	test_allin_help = 'Enrolls a bank of sTPM Endorsement Keys'
	test_allin_epilog = ''
	parser_test_allin = subparsers.add_parser('allin',
						help = test_allin_help,
						epilog = test_allin_epilog)
	parser_test_allin.set_defaults(func = cmd_test_allin)

	# ::allout
	test_allout_help = 'Unenrolls a bank of sTPM Endorsement Keys'
	test_allout_epilog = ''
	parser_test_allout = subparsers.add_parser('allout',
						help = test_allout_help,
						epilog = test_allout_epilog)
	parser_test_allout.set_defaults(func = cmd_test_allout)

	# ::allstart
	test_allstart_help = 'Starts a bank of sTPM (service) instances'
	test_allstart_epilog = ''
	parser_test_allstart = subparsers.add_parser('allstart',
						help = test_allstart_help,
						epilog = test_allstart_epilog)
	parser_test_allstart.set_defaults(func = cmd_test_allstart)

	# ::allstop
	test_allstop_help = 'Stops a bank of sTPM (service) instances'
	test_allstop_epilog = ''
	parser_test_allstop = subparsers.add_parser('allstop',
						help = test_allstop_help,
						epilog = test_allstop_epilog)
	parser_test_allstop.set_defaults(func = cmd_test_allstop)

	# ::soak
	test_soak_help = 'Soak-tests Enrollment and/or Attestation services'
	test_soak_epilog = """
This command uses an existing bank of sTPM instances (the 'create'
command must have already instanted them) to hit HCP services with a
randomized selection of Enrollment and Attestation requests.

* '--threads' (default=1) specifies how many threads to run.

* '--loop' (default=20) specifies how many iterations/requests to
  perform in each thread.

* For each iteration, a currently-unused (unlocked) sTPM EK is randomly chosen
  from the bank and locked for until the iteration is complete. If the
  chosen EK is not currently enrolled, the iteration will perform an
  enrollment operation, otherwise it will perform either an
  unenrollment operation or an attestation operation with that EK.

* '--pcattest' ("percentage of attest", default=0) is used to bias the
  random selection between an unenrollment or attestation operation.
  If --pcattest is 100 the choice will always be attestation, if it is
  0 the choice will always be unenrollment.
	"""
	test_soak_help_loop = 'number of iterations in the core loop'
	test_soak_help_threads = 'number of core loops to run in parallel'
	test_soak_help_pcattest = 'percentage of iterations that attest'
	parser_test_soak = subparsers.add_parser('soak',
						help = test_soak_help,
						epilog = test_soak_epilog,
						formatter_class = fc)
	parser_test_soak.add_argument('--loop',
				      type = int,
				      default = 20,
				      help = test_soak_help_loop)
	parser_test_soak.add_argument('--threads',
				      type = int,
				      default = 1,
				      help = test_soak_help_threads)
	parser_test_soak.add_argument('--pcattest',
				      type = int,
				      default = 0,
				      help = test_soak_help_pcattest)
	parser_test_soak.set_defaults(func = cmd_test_soak)

	# Process the command line
	func = None
	args = parser.parse_args()
	print(args)
	if not args.func:
		print("Error, no subcommand provided")
		sys.exit(-1)
	if not args.enrollapi:
		print("Error, no Enrollment Service API URL was provided")
		sys.exit(-1)
	if not args.attestapi:
		print("Error, no Attestation Service URL was provided")
		sys.exit(-1)
	args.func(args)
