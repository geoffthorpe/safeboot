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

docker_run_preamble = ['docker', 'run']

pp = pprint.PrettyPrinter(indent=4)

class Hcp:
	# - Provide 'hcp' _OR_ 'prefix'/'suffix' to specify the namespace for
	#   Docker objects, or neither to assume the default.
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
	def __init__(self, *, hcp=None, prefix='safeboot_hcp_', suffix='devel',
		     util=None,flags=None, mounts=None):
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
		self.envs = {}

	# Given an image name, elaborate it with prefix/suffix namespace info
	# (and the ":") for something docker-run can use.
	# - Returns string of the form <image:tag>
	def img_name(self, name):
		return self.prefix + name + ':' + self.suffix

	# Launch a container in this namespace. This would typically be used
	# internally by a derived class, which knows about the particular
	# service or function it's trying to launch.
	# - If 'name' is None, the utility container is launched. Otherwise
	#   'name' is a string that is passed through img_name() to determine
	#   the container image to be launched.
	# - 'cmd' is an array of strings, that are passed to "docker run"
	#   right after the image name.
	# - 'flags' and 'mounts' take the same form as they do in the
	#   constructor, though they only take effect during this call.
	# Returns 'CompletedProcess' struct from os.subprocess.run()
	def launch(self, name, cmd, *, flags=None, mounts=None):
		args = docker_run_preamble.copy()
		args += self.flags
		if (flags):
			args += flags
		if (mounts):
			mounts = self.mounts + mounts
		else:
			mounts = self.mounts
		for m in mounts:
			args.append('-v')
			s = m['source'] + ':' + m['dest']
			args.append(s)
		for e in self.envs:
			args.append('--env')
			s = e + '=' + self.envs[e]
			args.append(s)
		if name:
			args.append(self.img_name(name))
		else:
			args.append(self.util)
		args += cmd
		print('Running:', args)
		outcome = subprocess.run(args)
		print('Outcome:', outcome)
		return outcome

class HcpService(Hcp):

	# This is a base class for HCP services (HcpEnrollsvc, HcpAttestsvc,
	# HcpSwtpmsvc), where each object represents a stateful instance.
	# - 'path' specifies the directory where the instance should be,
	#   otherwise a randomly-generated directory is chosen.
	# - all other constructor parameters are passed through to the Hcp
	#   constructor.
	# Note, this constructor ensures the directory for the instance exists,
	# it does not determine whether (or not) the instance has already been
	# initialized. See ::Initialized().
	def __init__(self, *, path=None, **kwargs):
		super().__init__(**kwargs)
		self.latched = False
		self.running = False
		if not path:
			self.path = tempfile.mkdtemp()
		else:
			self.path = path
			if not os.path.isdir(path):
				os.mkdir(self.path)
		self.mounts.append({'source': self.path, 'dest': '/state'})

	# This run-time check is used to determine whether or not an instance
	# has done its service-specific initialization. Each derived class
	# should implement the boolean-valued handler "svcInitialized" to
	# perform the actual check. (The path is passed to the handler as a
	# parameter, to maintain some semblance of encapsulation, despite
	# python.) If this ever returns True, we cache that (as "latched") so
	# that we are not repeatedly testing an already-initialized instance,
	# but we never cache the False case - as double-initialization (e.g. in
	# a loosely-written test-case) can be very gnarly to untangle.
	# - Returns boolean.
	def Initialized(self):
		if not self.latched:
			self.latched = self.svcInitialized(self.path)
		return self.latched

	# Note, derived classes do not implement the actual initialization
	# routine! Rather, the derived class configures container image and
	# command information in its constructor, so the base class
	# implementation can do the launching for it. I.e. the service
	# specifics are in the container image, not the python class that
	# represents it. (Conversely, detecting whether initialization has
	# already occurred is typically not performed by a container, which is
	# why the python class has to specialize that.)
	# - Returns 'CompletedProcess' struct from os.subprocess.run(), or None
	#   if the instance was already initialized.
	def Initialize(self):
		if not self.Initialized():
			return self.launch(self.contName, self.initCmd,
					      flags=['-t','--rm'])
		return None

	# Destroys an initialized instance. Note, there is no specialization for
	# derived classes - deleting an instance is presumed to be equivalent to
	# deleting its state. To avoid namespace weirdness, we use the utility
	# container to do our deleting for us.
	# - Returns 'CompletedProcess' struct from os.subprocess.run(), or None
	#   if the instance wasn't initialized.
	def Delete(self):
		outcome = None
		if self.Initialized():
			outcome = self.launch(None,
				['bash', '-c', 'cd /state && rm -rf *'],
				flags=['-t','--rm'])
		if os.path.isdir(self.path):
			os.rmdir(self.path)
		return outcome

class HcpSwtpmsvc(HcpService):

	# Specializes HcpService to represent the HCP 'swtpmsvc' container
	# image (software TPM).
	# - 'enrollHostname' specifies the hostname that the software TPM
	#   should be bound to, as/when it gets enrolled.
	# - all other constructor parameters are passed through to the
	#   HcpService constructor.
	def __init__(self, *,
		     enrollHostname='nada.nothing.xyz',
		     **kwargs):
		super().__init__(**kwargs)
		self.contName = 'swtpmsvc'
		self.initCmd = ['/hcp/swtpmsvc/setup_swtpm.sh']
		self.envs['HCP_SWTPMSVC_STATE_PREFIX'] = '/state'
		self.envs['HCP_SWTPMSVC_ENROLL_HOSTNAME'] = enrollHostname

	# Obligatory handler, to detect if the instance has already been set
	# up. We use the presence/absence of the 'tpm' sub-directory to
	# determine this.
	def svcInitialized(self, path):
		return os.path.isdir(path + '/tpm')
