#!/usr/bin/python3

import os
from tempfile import mkdtemp
from multiprocessing import Lock
from random import randrange
from pathlib import Path
from hashlib import sha256
from multiprocessing import Process

from hcp import HcpSwtpmsvc
from enroll_api import enroll_add, enroll_delete, enroll_find

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

	def __init__(self, *, num=0, path=None, enrollAPI='http://localhost:5000'):
		self.path = path
		self.enrollAPI = enrollAPI
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
			entry['touchEnrolled'] = entry['path'] + '/enrolled'
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
		for entry in self.entries:
			if not entry['tpm']:
				entry['tpm'] = HcpSwtpmsvc(path=entry['path'])
				entry['tpm'].Initialize()
				grind = sha256()
				grind.update(open(entry['tpmEKpub'], 'rb').read())
				grind.update(open(entry['tpmEKpem'], 'rb').read())
				digest = grind.digest()
				entry['hostname'] = digest[:4].hex() + '.nothing.xyz'
				print('Initialized {num} at {path}'.format(
					num = entry['index'],
					path = entry['path']))

	def Delete(self):
		for entry in self.entries:
			print('Deleting {num} at {path}'.format(
				num = entry['index'],
				path = entry['path']))
			if not entry['tpm']:
				entry['tpm'] = HcpSwtpmsvc(path=entry['path'])
			pathPath = Path(entry['touchEnrolled'])
			if pathPath.is_file():
				pathPath.unlink()
			entry['tpm'].Delete()
			entry['tpm'] = None
		Path(self.numFile).unlink()
		os.rmdir(self.path)

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
		if os.path.isfile(entry['touchEnrolled']):
			# It's enrolled. Choose whether to attest or unenroll it.
			if pcattest > randrange(0, 100):
				# attest
				print('{idx} enrolled, attesting.'.format(idx=idx), end=' ')
				# Unimplemented...
				# self.Soak_locked_attest(entry)
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
			raise Exception('Enrollment \'add\' failed')
		Path(entry['touchEnrolled']).touch()

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
		Path(entry['touchEnrolled']).unlink()

if __name__ == '__main__':

	import argparse
	import sys

	def cmd_test_common(args):
		if not args.path:
			print("Error, no path provided (--path)")
			sys.exit(-1)
		args.bank = HcpSwtpmBank(path = args.path,
				    num = args.num,
				    enrollAPI = args.enrollapi)
	def cmd_test_create(args):
		cmd_test_common(args)
		args.bank.Initialize()

	def cmd_test_delete(args):
		cmd_test_common(args)
		args.bank.Delete()

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
  '--path'), it will fallback to using the 'EKBANK_PATH' environment
  variable.

* If the number of entries to use in the corpus is not supplied (via
  '--num') it is presumed that the bank already exists.

* If the base URL for the Enrollment Service's management API is not
  supplied on the command line (via '--enrollapi'), it will fallback
  to using the 'ENROLLSVC_API_URL' environment variable.

* If the URL for the Attestation Service is not supplied on the
  command line (via '--attestapi'), it will fallback to using the
  'ATTESTSVC_API_URL' environment variable.

To see subcommand-specific help, pass '-h' to the subcommand.
	"""
	test_help_path = 'path for the corpus'
	test_help_num = 'number of instances/EKpubs to support'
	test_help_enrollapi = 'base URL for the Enrollment Service management interface'
	test_help_attestapi = 'URL for the Attestation Service interface'
	parser = argparse.ArgumentParser(description = test_desc,
					 epilog = test_epilog,
					 formatter_class = fc)
	parser.add_argument('--path',
			   default = os.environ.get('EKBANK_PATH'),
			   help = test_help_path)
	parser.add_argument('--num',
			   type = int,
			   default = 0,
			   help = test_help_num)
	parser.add_argument('--enrollapi', metavar='<URL>',
			    default = os.environ.get('ENROLLSVC_API_URL'),
			    help = test_help_enrollapi)
	parser.add_argument('--attestapi', metavar='<URL>',
			    default = os.environ.get('ATTESTSVC_API_URL'),
			    help = test_help_attestapi)
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
