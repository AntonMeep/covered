version(unittest) {
	version(D_Coverage) shared static this() {
		import core.runtime : dmd_coverDestPath;
		import std.file : exists, mkdir;

		enum COVPATH = "coverage";

		if(!COVPATH.exists)
			COVPATH.mkdir;
		dmd_coverDestPath(COVPATH);
	}

	import std.stdio : writeln;
	import unit_threaded : runTests;

	int main(string[] args) {
		version(D_Coverage) writeln("Running code coverage analysis...");
		writeln("Running unit tests...");
		return runTests!("covered.loader")(args);
	}
} else {
	import covered.commandline;
	int main(string[] args) { return coveredMain(args); }
}
