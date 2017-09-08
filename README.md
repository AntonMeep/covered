Covered [![Page on DUB](https://img.shields.io/dub/v/covered.svg?style=flat-square)](http://code.dlang.org/packages/covered)[![License](https://img.shields.io/dub/l/covered.svg?style=flat-square)](https://github.com/ohdatboi/covered/blob/master/LICENSE)[![Build Status TravisCI](https://img.shields.io/travis/ohdatboi/covered/master.svg?style=flat-square)](https://travis-ci.org/ohdatboi/covered)[![Build status AppVeyor](https://img.shields.io/appveyor/ci/ohdatboi/covered/master.svg?style=flat-square)](https://ci.appveyor.com/project/ohdatboi/covered)
=============

**Covered** processes output of code coverage analysis performed by the D programming language compiler (DMD/LDC/GDC).

## Usage:

```
Usage:	covered <options> files dirs

Covered processes output of code coverage analysis performed by the D programming language compiler (DMD/LDC/GDC)

Every option below works with any number of files/directories specified in command line.
If nothing is specified, it looks for '*.lst' files in current working directory

Options:
-c  --coverage Reports code coverage (default)
-s    --source Shows source code, number of executions of each line, and it's code coverage
-b     --blame Shows list of files ordered by code coverage
-a   --average Reports average code coverage across all passed files
-j      --json Makes a dump in JSON format
-v   --verbose Verbose output
-h    --hidden When directory is passed, looks for hidden files as well (default: false)
-r --recursive When directory is passed, looks for *.lst files recursively (default: false)
-h      --help This help information.
```

## Installation:

```
$ dub fetch covered # Downloads covered
$ dub run covered # Runs covered
```

## Available options and examples
### `--coverage` - Prints code coverage for each passed file (default option)

```
$ ./covered sample/hello.lst
hello.d is 100.00% covered
```

### `--source` - Shows source code, number of executions of each line and it's code coverage

```
$ ./covered --source sample/hello.lst
+-------------------
| File: sample/hello.lst
| Source file: hello.d
| Coverage: 100.00%
+-------------------
import std.stdio;

void main() {
        writeln("Hello world!");
}
```

### `--blame` - Shows list of files ordered by coverage
```
$ ./covered --blame sample/hello.lst
                                           hello.d | 100.00%
```

### `--average` - Shows average total coverage of all passed files
```
$ ./covered --average sample/hello.lst
Average: 100.00%
```

## Performing code coverage analysis with DUB:

```
$ dub -b unittest-cov
```

This command will build and run your DUB project. Your program will create many `*.lst` files in your working dir. Covered uses those files:

```
$ dub run covered
```

You can pass aditional options to covered after `--`:
```
$ dub run covered -- --help
```

## Performing code coverage analysis like a pro:

Running `dub -b unittest-cov` leads to some problems:

1. It pollutes your working directory with tons of `*.lst` files.
2. Built-in `unittest`s are not that useful. Failed `unittest` exits program, so it is impossible to say, how many of them have been failed.
3. Built-in `assert`s, which are used in `unittest` blocks, are not that useful. `assert` just throws if value is not `true`, so it is very hard to say, why assertion failed.

Those problems doesn't make development impossible, but harder and slower.

### Moving `*.lst` files into separate directory:

Add this code to your app:

```D
version(D_Coverage) shared static this() {
	import core.runtime : dmd_coverDestPath;
	import std.file : exists, mkdir;

	enum COVPATH = "coverage";

	if(!COVPATH.exists) // Compiler won't create this directory
		COVPATH.mkdir; // That's why it should be done manually
	dmd_coverDestPath(COVPATH); // Now all *.lst files are written into ./coverage/ directory
}
```

Do not forget to add `./coverage` directory into your `.gitignore`:
```
coverage/
```

Ta-Da! Your working directory is no longer polluted

### Use cool unit-testing library

There are lots of them, but I will describe use of [unit-threaded](https://github.com/atilaneves/unit-threaded).

#### 1. Add entry to `dub.json`

```JSON
"configurations": [
	{ "name": "executable" },
	{
		"name": "unittest",
		"targetType": "executable",
		"preBuildCommands": [
			"dub run unit-threaded -c gen_ut_main -- -f .dub/ut.d"
		],
		"mainSourceFile": ".dub/ut.d",
		"dependencies": {
			"unit-threaded": "~>0.7.28",
			"fluent-asserts": "~>0.6.1"
		},
		"targetPath": ".dub/",
		"targetName": "unittester"
	}
],
```

If you want to use it *and* move `*.lst` into separate directory, copy it's code into some file (`cov.d`, for example), and add to your dub.json:

```JSON
"configurations": [
	{ "name": "executable" },
	{
		"name": "unittest",
		....
		"sourceFiles": ["cov.d"]
	}
],
```

#### 2. Use it!

```
$ dub test
```

Will run unittests with help of unit_threaded. Go to it's documentation for more information.

### Use fluent-asserts instead of built-in assertions.

Just use [fluent-asserts](https://github.com/gedaiu/fluent-asserts/). And again, go to it's documentation for more.

### Put it all together!

```
$ dub -b unittest-cov -c unittest
```

Will build and run your application with all `*.lst` files moved into `./coverage` directory, unittests runned in parallel, and nice messages if something goes wrong.

```
$ dub run covered -- ./coverage
```

That's it! Now you're performing code coverage analysis like a pro! Take a cookie: :cookie:
