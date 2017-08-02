module covered.commandline;

import covered.loader;
import std.array : array;
import std.algorithm : each, map, filter, joiner, sort, sum;
import std.getopt : getopt, defaultGetoptPrinter, config;
import std.file : exists, isDir, getcwd, dirEntries, SpanMode;
import std.path : extension;
import std.parallelism : taskPool;
import std.range : tee, chain, enumerate;
import std.stdio;
import std.string : rightJustify;

enum MODE {
	SIMPLE,
	SOURCE,
	BLAME,
	AVERAGE,
	FIX,
}

int coveredMain(string[] args) {
	string[] m_files;
	string[] m_dirs;
	bool m_verbose;
	MODE m_mode;

	void parseMode(string option) {
		switch(option) {
		case "coverage|c":
			m_mode = MODE.SIMPLE;
			break;
		case "source|s":
			m_mode = MODE.SOURCE;
			break;
		case "blame|b":
			m_mode = MODE.BLAME;
			break;
		case "average|a":
			m_mode = MODE.AVERAGE;
			break;
		case "fix|f":
			m_mode = MODE.FIX;
			break;
		default: assert(0);
		}
	}

	auto hlp = getopt(
		args,
		config.passThrough,
		"coverage|c", "Reports code coverage (default)", &parseMode,
		"source|s", "Shows source code, number of executions of each line, and it's code coverage", &parseMode,
		"blame|b", "Shows list of files ordered by code coverage", &parseMode,
		"average|a", "Reports average code coverage across all passed files", &parseMode,
		"fix|f", "Shows not covered parts of file", &parseMode,
		"verbose|v", "Verbose output", &m_verbose
	);

	if(hlp.helpWanted) {
		defaultGetoptPrinter(
			"Usage:\tcovered <options> files dirs\n\n" ~
			"Covered processes output of code coverage analysis performed by the D programming language compiler (DMD/LDC/GDC)\n\n" ~
			"Every option below works with any number of files/directories specified in command line.\n" ~
			"If nothing is specified, it looks for '*.lst' files in current working directory\n\n" ~
			"Options:", hlp.options);
		return 0;
	}

	args = args[1..$]; // Delete 1st argument (program name)

	foreach(a; args) { // Process other arguments
		if(a.exists) {
			if(a.isDir) {
				m_dirs ~= a;
			} else {
				if(a.extension == ".lst") {
					m_files ~= a;
				} else {
					stderr.writefln("Warning: %s is not an '*.lst' file", a); // It is allowed to pass non-lst files, but this warning will be shown
					m_files ~= a;
				}
			}
		} else {
			stderr.writefln("Error: %s doesn't exist", a);
		}
	}

	if(!m_files.length && !m_dirs.length) // If nothing passed, try current working dir
		m_dirs ~= getcwd();

	final switch(m_mode) with(MODE) {
	case SIMPLE:
		m_files.openFilesDirs(m_dirs)
			.each!(a =>a.getCoverage() == float.infinity
				? writefln("%s has no code", a.getSourceFile)
				: writefln("%s is %.2f%% covered", a.getSourceFile, a.getCoverage));
		break;
	case SOURCE:
		// m_files.openFilesDirs(m_dirs)
		// 	.map!(a => a.loadCoverage)
		// 	.each!((a) {
		// 		writeln("+-------------------");
		// 		writefln("| File: %s", a.getName);
		// 		writefln("| Source file: %s", a.sourceFile);
		// 		if(a.coverage == float.infinity) {
		// 			writefln("| Coverage: none (no code)", a.sourceFile);
		// 		} else {
		// 			writefln("| Coverage: %.2f%%", a.getCoverage);
		// 		}
		// 		writeln("+-------------------");
		// 		a.byEntry
		// 			.each!(x => m_verbose
		// 				? x.Used
		// 					? "%5d|%s".writefln(x.Count, x.Source)
		// 					: "     |%s".writefln(x.Source)
		// 				: x.Source.writeln);
		// 	});
		break;
	case BLAME:
		// taskPool
		// 	.map!(loadCoverage)(m_files.openFilesDirs(m_dirs))
		// 	.array
		// 	.sort!((a, b) => a.coverage < b.coverage)
		// 	.filter!(a => a.coverage != float.infinity)
		// 	.each!(a => m_verbose
		// 		? "%-50s | %-50s | %.2f%%".writefln(
		// 			a.sourceName.length > 50
		// 				? a.sourceName[$-50..$]
		// 				: a.sourceName.rightJustify(50),
		// 			a.resultName.length > 50
		// 				? a.resultName[$-50..$]
		// 				: a.resultName.rightJustify(50),
		// 			a.coverage)
		// 		: "%-50s | %.2f%%".writefln(
		// 			a.sourceName.length > 50
		// 				? a.sourceName[$-50..$]
		// 				: a.sourceName.rightJustify(50),
		// 			a.coverage));
		break;
	case AVERAGE:
		// size_t count;
		// "Average: %.2f%%"
		// 	.writefln(taskPool
		// 		.map!(loadCoverage)(m_files.openFilesDirs(m_dirs))
		// 		.filter!(a => a.coverage != float.infinity)
		// 		.map!(a => a.coverage)
		// 		.tee!(a => ++count)
		// 		.sum / count);
		break;
	case FIX:
		// size_t last;
		// m_files.openFilesDirs(m_dirs)
		// 	.map!(a => a.loadCoverage)
		// 	.filter!(a => a.coverage != float.infinity && a.coverage != 100.0f)
		// 	.each!((a) {
		// 		writeln("+-------------------");
		// 		writefln("| Source file: %s", a.sourceName);
		// 		writeln("+-------------------");
		// 		a.source
		// 			.enumerate(1)
		// 			.filter!(x => x[1].used && x[1].count == 0)
		// 			.each!((x) {
		// 				if(last + 1 != x[0])
		// 					writeln(".....|");
		// 				last = x[0];

		// 				"%5d| %s".writefln(x[0], x[1].source);
		// 			});
		// 	});
		break;
	}
	return 0;
}
