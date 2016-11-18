---------------------INSTAL----------------------

----KITURA----
 Install the following Linux system packages:
$ sudo apt-get update
$ sudo apt-get install clang libicu-dev libcurl4-openssl-dev libssl-dev

Download a Swift 3.0.1 toolchain from:
https://swift.org/download/

update your PATH environment variable
$ export PATH=<path to uncompressed tar contents>/usr/bin:$PATH


----REDIS----
Download, extract and compile Redis with:
$ wget http://download.redis.io/releases/redis-3.2.5.tar.gz
$ tar xzf redis-3.2.5.tar.gz
$ cd redis-3.2.5
$ make


----FIX PATH----
Open bash.bashrc
$ sudo gedit /etc/bash.bashrc

Add the ligne in he end:
	SWIFT_PATH=<path to uncompressed tar contents>/usr/bin
	PATH=$SWIFT_PATH:$PATH

	export SWIWF_PATH
	export PATH


----Sublime text----
Install
$ sudo add-apt-repository ppa:webupd8team/sublime-text-3
$ sudo apt-get update
$ sudo apt-get install sublime-text-installer

Color sintax:
https://github.com/quiqueg/Swift-Sublime-Package


---------------------------------------------
