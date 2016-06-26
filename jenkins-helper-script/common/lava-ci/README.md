# LAVA-CI
## Configuration using $HOME/.lavarc

```
$ cat $HOME/.lavarc
[linaro]
server: http://lava-server/RPC2
username: <user>
token: <auth-token>
```

## Usage instructions for lava-stream-job:
The only required option is "--job", everything else can be configured through either $HOME/.lavarc or the environment.
```
./lava-stream-log.py [-h] [--username <lava username>] [--token <lava token>] [--server <http://lava-server/RPC2>] --job <lava job id>
```
Examples:
```
./lava-stream-log.py --username <lava username> --token <lava token> --server <http://lava-server/RPC2> --job <lava job id>
./lava-stream-log.py --section linaro --job <lava job id>

# Override config settings on the command line
./lava-stream-log.py --section linaro --token <lava token> --job <lava job id>
```

## Usage instructions for lava-kernel-ci-job-creator.py:
This command line tool will create LAVA boot test jobs for various architectures, and platforms.
```
./lava-kernel-ci-job-creator.py [-h] --plans PLANS [PLANS ...] [--arch ARCH] [--targets TARGETS [TARGETS ...]] url
```
Examples:
```
# Create all LAVA boot test jobs for a specific build.
./lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20150114/ --plans boot

# Create only LAVA boot test jobs for a specific build and architecture.
./lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20150114/ --plans boot --arch arm

# Create only LAVA boot test jobs for a specific build and targets.
./lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20150114/ --plans boot --targets mustang odroid-xu3
```
The generated jobs can be found in the jobs directory.


## Usage instructions for lava-job-runner.py:
This command line tool will submit all LAVA jobs in the current working directory.
```
./lava-job-runner.py [-h] [--stream STREAM] [--repo REPO] [--poll POLL]
```
Examples:

```
# Submit all LAVA jobs in the current working directory to a specific server, and bundle stream.
./lava-job-runner.py --username <lava username> --token <lava token> --server <http://lava-server/RPC2> --stream /anonymous/mybundle/

# Submit and poll all LAVA jobs in the current working directory to a specific server, bundle stream.
./lava-job-runner.py --username <lava username> --token <lava token> --server <http://lava-server/RPC2> --stream /anonymous/mybundle/ --boot results/kernel-ci.json

# Submit and poll all LAVA jobs in the current working directory to a specific server, bundle stream. Once the results have been obtained, store the results in a JSON encoded file for use later with the dashboard reporting tool.
./lava-job-runner.py <username> <lava token> http://my.lavaserver.com/RPC2/ --stream /anonymous/mybundle/ --boot results/kernel-ci.json --lab <lab-id> --api http://api.kernelci.org --token <dashboard token>
```

## Usage instructions for lava-report.py:
This command line tool will report the results of LAVA jobs given a JSON results file.
```
./lava-report.py [-h] [--boot BOOT] [--lab LAB] [--api API] [--token TOKEN] [--email EMAIL]
```
Examples:

```
# Report all results from a given JSON result file.
./lava-report.py --boot results/kernel-ci.json --lab <lab-id> --api http://api.kernelci.org --token <dashboard token>
```
The generated results can be found in the results directory.

## Configure LAVA

From the admin panel, you have to create a group named `kernel-ci`, a user named `kernel-ci` and its authentication token, and add it to the members of the group.

You must create a new anonymous bundle stream named `kernel-ci` so KernelCI can retrieve the boot reports from your LAVA instance.

## Add board to KernelCI
### Add board to LAVA

You have to create a new device\_type in your LAVA dispatcher instance. The file should be named after its dtb's name in the kernel sources (e.g.: `armada-388-clearfog` for the Solidrun ClearFog). Then, you can create a new device in your LAVA dispatcher instance and name this file whatever you want.

You should now add the device\_type and device from your LAVA admin panel. If you want your device to be tested by KernelCI, it has to be owned by the group `kernel-ci`.

### Modify files

To add your board to KernelCI, you will have to modify two files:

- lava-kernel-ci-job-creator.py:

You need to create a dictionary for your board as following:

```
armada_388_clearfog = {'device_type': 'armada-388-clearfog',
                    'templates': ['generic-arm-dtb-kernel-ci-boot-template.json'],
                    'defconfig_blacklist': ['arm-allmodconfig'],
                    'kernel_blacklist': [],
                    'nfs_blacklist': [],
                    'lpae': False,
                    'fastboot': False}
```

`armada_388_clearfog` is the local variable name in this program, it is advisable to use the device\_type name (note that the dash (-) character cannot be used in variables' name in Python so you may replace them with underscores (\_)).

`armada-388-clearfog` is the name of your LAVA device\_type and, as strongly advised above, should be the name of the board's dtb in kernel sources.

The `templates` array represents the templates used to create jobs for the specified board. All templates can be found in the subdirectory templates.

The `nfs_blacklist` array is an array of substrings of a kernel version you should not boot with NFS.

If `lpae` is set to False and the name of the defconfig contains `LPAE`, this job will not be created for this board.

Then, you need to create an entry for you board in the device\_map dictionary:

```
device_map = {[...],
              'armada-388-clearfog.dtb': [armada_388_clearfog],
              [...]}
```

`armada-388-clearfog.dtb` is the name of the dtb in kernel sources and `armada_388_clearfog` is the local variable name you used previously to name your board's dictionary.

- lava-report.py:

You need to add an entry for your board in the device\_map dictionary:

```
device_map = {[...],
              'armada-388-clearfog': ['armada-388-clearfog', 'mvebu'],
              [...]}
```

The first `armada-388-clearfog` is the name of of your LAVA device\_type while the second is the name which will be displayed in KernelCI dashboard.

`mvebu` is the SoC name of the board and also where the board will be found in KernelCI dashboard.

### Add your lab to KernelCI
If you did everything as explained above, send them a mail with the authentication token for user `kernel-ci` and make your LAVA instance (at least the XMLRPC API which is located at /RPC2) available from Internet.

Before sending the mail, test your board by running lava-kernel-ci-job-creator.py then lava-job-runner.py.

If you want to add a board to your lab which already exists in KernelCI, make sure your LAVA device\_type matches the name used in lava-kernel-ci-job-creator.py.
