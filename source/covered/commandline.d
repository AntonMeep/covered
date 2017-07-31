module covered.commandline;

import covered.loader;
import std.array : array;
import std.algorithm : each, map, filter, joiner, sort, sum;
import std.getopt : getopt, defaultGetoptPrinter, config;
import std.file : exists, isDir, getcwd;
import std.path : extension;
import std.range : tee, chain;
import std.stdio;

enum MODE {
	SIMPLE,
	SOURCE,
	BLAME,
	AVERAGE,
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
		m_files
			.filter!(a => a.exists)
			.map!(a => CoverageLoader(a))
			.chain(m_dirs.filter!(a => a.exists).map!(a => a.openDir).joiner)
			.each!(a => a.coverage == float.infinity
				? writefln("%s has no code", a.sourceName)
				: writefln("%s is %.2f%% covered", a.sourceName, a.coverage));
			break;
	case SOURCE:
		m_files
			.filter!(a => a.exists)
			.map!(a => CoverageLoader(a))
			.chain(m_dirs.filter!(a => a.exists).map!(a => a.openDir).joiner)
			.each!((a) {
				writeln("+-------------------");
				writefln("| File: %s", a.resultName);
				writefln("| Source file: %s", a.sourceName);
				if(a.coverage == float.infinity) {
					writefln("| Coverage: none (no code)", a.sourceName);
				} else {
					writefln("| Coverage: %.2f%%", a.coverage);
				}
				writeln("+-------------------");
				a.source
					.each!(x => m_verbose
						? x.used
							? "%5d|%s".writefln(x.count, x.source)
							: "     |%s".writefln(x.source)
						: x.source.writeln);
			});
		break;
	case BLAME:
		m_files
			.filter!(a => a.exists)
			.map!(a => CoverageLoader(a))
			.chain(m_dirs.filter!(a => a.exists).map!(a => a.openDir).joiner)
			.filter!(a => a.coverage != float.infinity)
			.array
			.sort!((a, b) => a.coverage < b.coverage)
			.each!(a => m_verbose
			       ? writefln("%-40s | %-60s | %.2f%%", a.sourceName, a.resultName, a.coverage)
			       : writefln("%-40s | %.2f%%", a.sourceName, a.coverage));
		break;
	case AVERAGE:
		size_t count;
		"Average: %.2f%%".writefln(m_files
			.filter!(a => a.exists)
			.map!(a => CoverageLoader(a))
			.chain(m_dirs.filter!(a => a.exists).map!(a => a.openDir).joiner)
			.filter!(a => a.coverage != float.infinity)
			.map!(a => a.coverage)
			.tee!(a => ++count)
			.sum / count);
		break;
	}
	return 0;
}
