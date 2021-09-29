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
			entry['tpmEKpub'] = entry['path'] + '/tpm/ek.pub'
			entry['tpmEKpem'] = entry['path'] + '/tpm/ek.pem'
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
			entry['tpm'].Delete()
			entry['tpm'] = None
		Path(self.numFile).unlink()
		os.rmdir(self.path)

	def Soakenroll(self, loop, threads):
		children = []
		for _ in range(threads):
			p = Process(target=self.Soakenroll_thread, args=(loop,))
			print('launching')
			p.start()
			children.append(p)
		while len(children):
			p = children.pop()
			print('joining')
			p.join()

	def Soakenroll_thread(self, loop):
		print(f'_thread, loop={loop}')
		for _ in range(loop):
			self.Soakenroll_iteration()

	def Soakenroll_iteration(self):
		print('_iteration')
		args = HcpArgs()
		args.api = self.enrollAPI
		idx = randrange(0, self.num)
		entry = self.entries[idx]
		entry['lock'].acquire()
		if os.path.isfile(entry['touchEnrolled']):
			print('{idx} enrolled, unenrolling.'.format(idx=idx), end=' ')
			if not entry['ekpubhash']:
				# Lazy initialize the ekpubhash value, using 'find'
				args.hostname_suffix = entry['hostname']
				result, jr = enroll_find(args)
				if not result:
					raise Exception('Enrollment \'find\' failed')
				num = len(jr['ekpubhashes'])
				if num != 1:
					raise Exception(f'Enrollment \'find\' return {num} hashes')
				entry['ekpubhash'] = jr['ekpubhashes'].pop()
				print('lazy-init ekpubhash={ekph}.'.format(
					ekph = entry['ekpubhash']), end=' ')
			args.ekpubhash = entry['ekpubhash']
			result, jr = enroll_delete(args)
			if not result:
				raise Exception('Enrollment \'delete\' failed')
			Path(entry['touchEnrolled']).unlink()
		else:
			print('{idx} unenrolled, enrolling.'.format(idx=idx), end=' ')
			pubOrPem = randrange(0, 2)
			if pubOrPem == 0:
				print('TPM2B_PUBLIC.', end=' ')
				args.ekpub = entry['tpmEKpub']
			else:
				print('PEM.', end=' ')
				args.ekpub = entry['tpmEKpem']
			args.hostname = entry['hostname']
			result, jr = enroll_add(args)
			if not result:
				raise Exception('Enrollment \'add\' failed')
			Path(entry['touchEnrolled']).touch()
		print('OK')
		entry['lock'].release()

if __name__ == '__main__':

	import argparse
	import sys

	def cmd_ekbank_common(args):
		if not args.path:
			print("Error, no path provided (--path)")
			sys.exit(-1)
		args.bank = HcpSwtpmBank(path = args.path,
				    num = args.num,
				    enrollAPI = args.api)
	def cmd_ekbank_create(args):
		cmd_ekbank_common(args)
		args.bank.Initialize()

	def cmd_ekbank_delete(args):
		cmd_ekbank_common(args)
		args.bank.Delete()

	def cmd_ekbank_soakenroll(args):
		cmd_ekbank_common(args)
		args.bank.Initialize()
		if args.loop < 1:
			print(f"Error, illegal loop value ({args.loop})")
			sys.exit(-1)
		if args.threads < 1:
			print(f"Error, illegal threads value ({args.threads})")
			sys.exit(-1)
		args.bank.Soakenroll(args.loop, args.threads)

	# Wrapper 'test' command
	test_desc = 'Toolkit for testing HCP services and functions'
	test_epilog = """
	If the URL for the Enrollment Service's management API is not supplied on the
	command line (via '--api'), it will fallback to using the 'ENROLLSVC_API_URL'
	environment variable.

	To see subcommand-specific help, pass '-h' to the subcommand.
	"""
	test_help_api = 'base URL for management interface'
	parser = argparse.ArgumentParser(description = test_desc,
					 epilog = test_epilog)
	parser.add_argument('--api', metavar='<URL>',
			    default = os.environ.get('ENROLLSVC_API_URL'),
			    help = test_help_api)
	subparsers = parser.add_subparsers()

	# ekbank
	ekbank_help = 'Manages a bank of sTPM instances'
	ekbank_epilog = """
	The ekbank commands manage a corpus of TPM EK (Endorsement Keys) for use in
	testing. If the path for the corpus is not supplied on the command line (via
	'--api'), it will fallback to using the 'EKBANK_PATH' environment variable.
	If the number of entries to use in the corpus is not supplied (via '--num')
	it is presumed that the bank already exists.

	To see subcommand-specific help, pass '-h' to the subcommand.
	"""
	ekbank_help_path = 'path for the corpus'
	ekbank_help_num = 'number of instances/EKpubs to support'
	parser_ekbank = subparsers.add_parser('ekbank',
					      help = ekbank_help,
					      epilog = ekbank_epilog)
	parser_ekbank.add_argument('--path',
				   default = os.environ.get('EKBANK_PATH'),
				   help = ekbank_help_path)
	parser_ekbank.add_argument('--num',
				   type = int,
				   default = 0,
				   help = ekbank_help_num)
	subparsers_ekbank = parser_ekbank.add_subparsers()

	# ekbank::create
	ekbank_create_help = 'Creates/updates a bank of sTPM instances'
	ekbank_create_epilog = ''
	parser_ekbank_create = subparsers_ekbank.add_parser('create',
						help = ekbank_create_help,
						epilog = ekbank_create_epilog)
	parser_ekbank_create.set_defaults(func = cmd_ekbank_create)

	# ekbank::delete
	ekbank_delete_help = 'Deletes a bank of sTPM instances'
	ekbank_delete_epilog = ''
	parser_ekbank_delete = subparsers_ekbank.add_parser('delete',
						help = ekbank_delete_help,
						epilog = ekbank_delete_epilog)
	parser_ekbank_delete.set_defaults(func = cmd_ekbank_delete)

	# ekbank::soakenroll
	ekbank_soakenroll_help = 'Soak tests an Enrollment Service using a bank of sTPM instances'
	ekbank_soakenroll_epilog = ''
	ekbank_soakenroll_help_loop = 'number of iterations in the core loop'
	ekbank_soakenroll_help_threads = 'number of core loops to run in parallel'
	parser_ekbank_soakenroll = subparsers_ekbank.add_parser('soakenroll',
						help = ekbank_soakenroll_help,
						epilog = ekbank_soakenroll_epilog)
	parser_ekbank_soakenroll.add_argument('--loop',
					      type = int,
					      default = 20,
					      help = ekbank_soakenroll_help_loop)
	parser_ekbank_soakenroll.add_argument('--threads',
					      type = int,
					      default = 1,
					      help = ekbank_soakenroll_help_threads)
	parser_ekbank_soakenroll.set_defaults(func = cmd_ekbank_soakenroll)

	# Process the command line
	func = None
	args = parser.parse_args()
	print(args)
	if not args.func:
		print("Error, no subcommand provided")
		sys.exit(-1)
	if not args.api:
		print("Error, no API URL was provided")
		sys.exit(-1)
	args.func(args)

#	bank = HcpSwtpmBank(path=os.getcwd() + '/fooo')
#	bank.Initialize()
#	for _ in range(100):
#		bank.Do()
#	bank.Delete()

