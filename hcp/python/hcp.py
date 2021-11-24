#!/usr/bin/python3

# OK, here goes. We have a small class hierarchy to represent the goings on of
# HCP state and containers, and to take care of invoking Docker.
#
# This is very incomplete, it only implements the bare minimum (so far) to
# allow for the creation of multiple swtpmsvc instances so that we have a bank
# of EKpub keys to soak-test the Enrollment and Attestation services with.
#
# class Hcp
# - This is a base class for everything else, and it's primary role is to
#   represent the idea of a container image namespace. E.g. the enrollsvc
#   container image is expected to be called 'foo_enrollsvc:bar', for some
#   'foo' and 'bar'. These are the 'prefix' and 'suffix', and collectively
#   that's the 'container image namespace'.
# - This also encapsulates the accumulation of 'flags', i.e. individual
#   command-line arguments passed to 'docker run'.
# - This also encapsulates the accumulation of 'mounts': 2-tuples of 'source'
#   and 'dest' strings that are treated as paths for bind-mounting. For each
#   such pair, '-v <source>:<dest>' is added to 'docker run' command lines.
# - A generic/raw 'launch' method is provided that can be invoked directly, but
#   is more likely invoked by derived classes.
#
# class HcpService
# - This is a base class, derived from Hcp, that represents an instance of an
#   HCP service. It encapsulates the state for the service, via a 'path'
#   provided to the constructor, resulting in a random/temp directory if
#   'path'==None.
# - Detecting whether the service state has been initialized is deferred to a
#   method that derived classes must implement.
# - The 'Initialize()' method launches the service container's setup script to
#   create service state.
# - The 'Delete()' method tears down the service state.
# - Start/Stop are unimplemented for now.
#
# class HcpSwtpmsvc
# - Derived from HcpService.
# - Sets object attributes allowing the service state to be initialized.

import subprocess
import tempfile
import os
import pprint
from pathlib import Path, PurePosixPath

docker_run_preamble = ['docker', 'run']

pp = pprint.PrettyPrinter(indent=4)

class Hcp:
	# - Provide 'net' _OR_ 'hcp' _OR_ 'prefix'/'suffix' to specify the
	#   namespace for Docker objects, or none to assume the defaults.
	# - If 'net' is provided, it should be an HcpNetwork object.
	# - If 'util' is provided, it is assumed to be full-qualified (not part
	#   of the current Hcp prefix/suffix namespace), e.g. "debian:latest".
	#   Otherwise the 'caboodle' image from the current namespace is taken
	#   as the utility container.
	# - 'flags' is an optional array of strings, specifying any cmd-line
	#   arguments that should be passed to any+all "docker run" invocations
	#   by this object.
	# - 'mounts' is an optional array of Dicts, specifying any host
	#   directories that should be mounted to any+all "docker run"
	#   invocations by this object. Each Dict consists of 'source' and
	#   'dest' string-valued fields, which specify the host path to be
	#   mounted and the container path it should show up as, respectively.
	# - 'labels' is an optional array of strings, each of which will be
	#   set to a value of 1 when launching a container.
	def __init__(self, *, net = None, hcp = None,
		     prefix = 'safeboot_hcp_', suffix = 'devel',
		     util = None, flags = None, mounts = None, labels = None):
		self.net = None
		if net:
			if hcp:
				raise Exception("'net' and 'hcp' are exclusive")
			self.net = net
			hcp = net
		if hcp:
			self.prefix = hcp.prefix
			self.suffix = hcp.suffix
		else:
			self.prefix = prefix
			self.suffix = suffix
		if util:
			self.util = util
		else:
			self.util = self.img_name('caboodle')
		self.flags = []
		if flags:
			self.flags += flags
		self.mounts = []
		if mounts:
			self.mounts += mounts
		self.netName = self.prefix + 'network'
		self.labels = [self.netName]
		if labels:
			self.labels += labels
		self.envs = {}

	# Given an image name, elaborate it with prefix/suffix namespace info
	# (and the ":") for something docker-run can use.
	# - Returns string of the form <image:tag>
	def img_name(self, name):
		return self.prefix + name + ':' + self.suffix

	# Similar, but without the ':'. E.g. used for container names
	def other_name(self, name):
		return self.prefix + name + self.suffix

	# Launch a container in this namespace. This would typically be used
	# internally by a derived class, which knows about the particular
	# service or function it's trying to launch.
	# - If 'imgName' is None, the utility container is launched. Otherwise
	#   it is a string that is passed through img_name() to determine the
	#   container image to be launched.
	# - 'cmd' is an array of strings, that are passed to "docker run"
	#   right after the image name.
	# - 'flags' and 'mounts' take the same form as they do in the
	#   constructor, though they only take effect during this call.
	# Returns 'CompletedProcess' struct from os.subprocess.run()
	def launch(self, imgName, cmd, *,
		   flags = None,
		   mounts = None,
		   labels = None,
		   contName = None,
		   hostName = None):
		args = docker_run_preamble.copy()
		args += self.flags
		if (flags):
			args += flags
		m = self.mounts
		if (mounts):
			m += mounts
		for x in m:
			args.append('-v')
			s = x['source'] + ':' + x['dest']
			args.append(s)
		for e in self.envs:
			args.append('--env')
			s = e + '=' + self.envs[e]
			args.append(s)
		if contName:
			args += ['--name', self.other_name(contName)]
		if hostName:
			args += ['--hostname', hostName]
		if self.net:
			args += ['--network', self.net.netName]
			if hostName:
				args += ['--network-alias', hostName]
			self.net.netInitialize()
		l = self.labels
		if labels:
			l += labels
		for x in l:
			args += ['--label', x]
		if imgName:
			args.append(self.img_name(imgName))
		else:
			args.append(self.util)
		args += cmd
		return self.raw_run(args)

	def raw_run(self, args):
		outcome = subprocess.run(args, capture_output = True)
		if outcome.returncode != 0:
			raise Exception('Failure when running; ' + ' '.join(args))
		return outcome

class HcpNetwork(Hcp):

	def __init__(self, **kwargs):
		super().__init__(**kwargs)
		self.lazyStarted = False
		outcome = subprocess.run(
			['docker', 'network', 'inspect', self.netName],
			capture_output = True)
		if outcome.returncode == 0:
			self.preExisting = True
		else:
			self.preExisting = False

	def netInitialize(self):
		if not self.preExisting and not self.lazyStarted:
			subprocess.run(['docker', 'network', 'create', self.netName])
			self.lazyStarted = True

	def netCleanup(self):
		if not self.preExisting and self.lazyStarted:
			subprocess.run(['docker', 'network', 'rm', self.netName])
			self.lazyStarted = False

class HcpFunction(Hcp):

	def __init__(self, **kwargs):
		super().__init__(**kwargs)
		self.labels = []
		self.contName = None
		self.hostName = None

	def Run(self, *, flags=None, **kwargs):
		f = ['-t','--rm']
		if flags:
			f += flags
		return self.launch(self.imgName, self.runCmd,
				   flags = f,
				   labels = self.labels,
				   contName = self.contName,
				   hostName = self.hostName,
				   **kwargs)

class HcpService(Hcp):

	def __init__(self, *, path = None, **kwargs):
		super().__init__(**kwargs)
		self.latched = False
		self.running = False
		self.checkedRunning = False
		if not path:
			self.dynamicPath = True
		else:
			self.dynamicPath = False
			self.path = Path(path)
		self.lazyConstruct()
		self.mounts.append({'source': str(self.path_state),
				    'dest': '/state'})
		self.ports = []
		self.labels = []
		self.contName = None
		self.hostName = None

	def lazyConstruct(self):
		if self.dynamicPath:
			self.path = Path(tempfile.mkdtemp())
		else:
			if not self.path.is_dir():
				self.path.mkdir()
		self.path_state = Path(self.path / 'state')
		self.path_init = Path(self.path / 'initialized')
		self.path_cid = Path(self.path / 'cid')
		# We always mount a subdirectory of our path, so that we
		# have a place to put metadata that the container can't
		# mangle.
		if not self.path_state.is_dir():
			self.path_state.mkdir()

	def checkRunning(self):
		cid = None
		if self.path_cid.is_file():
			lines = open(self.path_cid).readlines()
			if len(lines) == 1:
				cid = lines.pop()
		if cid:
			outcome = subprocess.run(
				['docker', 'container', 'inspect', cid],
				capture_output = True)
			if outcome.returncode == 0:
				self.running = True
		self.checkedRunning = True

	def Initialized(self):
		return self.path_init.is_file()

	def Initialize(self):
		if not self.Initialized():
			self.lazyConstruct()
			self.launch(self.imgName, self.initCmd,
				    flags=['-t','--rm'])
			self.path_init.touch()
		if not self.checkedRunning:
			self.checkRunning()
		return None

	def Running(self):
		if not self.checkedRunning:
			self.checkRunning()
		return self.running

	def Delete(self):
		outcome = None
		if self.Initialized():
			self.lazyConstruct()
			outcome = self.launch(self.imgName,
				['bash', '-c', 'cd /state && rm -rf *'],
				flags=['-t','--rm'])
			self.path_state.rmdir()
			self.path_init.unlink()
		if self.path_cid.is_file():
			self.path_cid.unlink()
		self.path.rmdir()
		return outcome

	def Start(self, **kwargs):
		self.Initialize()
		if not self.running:
			flags = ['-t','-d','--cidfile', str(self.path_cid)]
			for x in self.ports:
				s = f"--publish={x['host']}:{x['cont']}"
				flags.append(s)
			self.launch(self.imgName, self.startCmd,
				    flags = flags,
				    labels = self.labels,
				    contName = self.contName,
				    hostName = self.hostName,
				    **kwargs)
			self.running = True

	def Stop(self):
		self.Initialize()
		if self.running:
			with open(str(self.path_cid), 'r') as f:
				cid = f.readline()
			self.raw_run(['docker', 'container', 'stop', '--time=1', cid])
			self.raw_run(['docker', 'container', 'rm', cid])
			self.path_cid.unlink()
			self.running = False

class HcpAttestclient(HcpFunction):

	def __init__(self, *,
		     attestURL = 'http://attestsvc_hcp:8080',
		     tpm2TCTI = 'swtpm:host=swtpmsvc,port=9876',
		     contName = 'client',
		     hostName = 'client',
		     assetSigner = None,
		     **kwargs):
		super().__init__(**kwargs)
		self.imgName = 'client'
		self.runCmd = ['/hcp/client/run_client.sh']
		self.labels.append('HcpAttestclient')
		self.contName = contName
		self.hostName = hostName
		if assetSigner:
			p = Path(assetSigner)
			self.flags += ['-v', str(p) + ':/signer']
			self.envs['HCP_RUN_CLIENT_VERIFIER'] = '/signer'
		self.envs['HCP_CLIENT_ATTEST_URL'] = attestURL
		self.envs['HCP_RUN_CLIENT_TPM2TOOLS_TCTI'] = tpm2TCTI

class HcpSwtpmsvc(HcpService):

	def __init__(self, *,
		     enrollHostname = 'nada.nothing.xyz',
		     enrollAPI = None,
		     listenPort = 0,
		     contName = 'swtpmsvc',
		     hostName = 'swtpmsvc',
		     **kwargs):
		super().__init__(**kwargs)
		self.imgName = 'swtpmsvc'
		self.initCmd = ['/hcp/swtpmsvc/setup_swtpm.sh']
		self.startCmd = ['/hcp/swtpmsvc/run_swtpm.sh']
		self.labels.append('HcpSwtpmsvc')
		self.contName = contName
		self.hostName = hostName
		self.envs['HCP_SWTPMSVC_STATE_PREFIX'] = '/state'
		self.envs['HCP_SWTPMSVC_ENROLL_HOSTNAME'] = enrollHostname
		if enrollAPI:
			self.envs['HCP_SWTPMSVC_ENROLL_API'] = enrollAPI
		if listenPort > 0:
			self.ports.append({'host': listenPort,
					   'cont': 9876})

if __name__ == '__main__':
	import time
	from enroll_api import enroll_getAssetSigner
	class HcpArgs:
		pass
	net = HcpNetwork()
	path = os.getcwd() + '/Barney'
	assetSigner = tempfile.mkdtemp()
	args = HcpArgs()
	args.api = 'http://localhost:5000'
	args.output = assetSigner + '/key.pem'
	enroll_getAssetSigner(args)
	stpm = HcpSwtpmsvc(net = net, path = path,
			   util = 'debian:latest',
			   enrollAPI = 'http://enrollsvc_mgmt:5000',
			   listenPort = 9876)
	client = HcpAttestclient(net = net,
				 assetSigner = args.output)
	try:
		print('Try stpm.Initialize()')
		stpm.Initialize()
		print('Try stpm.Start()')
		stpm.Start()
		print('Try client.Run()')
		client.Run()
	finally:
		print('Doing the finally dance')
		stpm.Stop()
		stpm.Delete()
		net.netCleanup()
		Path(args.output).unlink()
		Path(assetSigner).rmdir()
