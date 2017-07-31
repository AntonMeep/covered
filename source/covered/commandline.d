module covered.commandline;

import covered.loader;
import std.stdio;
import std.getopt;
import std.file;
import std.path : extension;
import std.format : format;

enum MODE {
	SIMPLE,
	SOURCE,
	BLAME,
}

int coveredMain(string[] args) {
	string[] m_files;
	string[] m_dirs;
	bool m_verbose;
	MODE m_mode;

	void parseMode(string option) {
		switch(option) {
		case "coverage":
			m_mode = MODE.SIMPLE;
			break;
		case "source":
			m_mode = MODE.SOURCE;
			break;
		case "blame":
			m_mode = MODE.BLAME;
			break;
		default:
			break;
		}
	}

	auto hlp = getopt(
		args,
		config.passThrough,
		"coverage|c", "Reports code coverage (default)", &parseMode,
		"source", "Prints source code and reports code coverage", &parseMode,
		"blame", "Prints less covered files", &parseMode,
		"verbose|v", "Verbose output", &m_verbose
	);

	if(hlp.helpWanted) {
		defaultGetoptPrinter("Processes output of code coverage analysis", hlp.options);
		return 0;
	}

	args = args[1..$];

	foreach(a; args) {
		if(a.exists) {
			if(a.isDir) {
				m_dirs ~= a;
			} else {
				if(a.extension == ".lst") {
					m_files ~= a;
				} else {
					stderr.writefln("Warning: %s is not an '*.lst' file", a);
					m_files ~= a;
				}
			}
		} else {
			stderr.writefln("Error: %s doesn't exist", a);
		}
	}

	if(!m_files.length && !m_dirs.length)
		m_dirs ~= getcwd();

	import std.algorithm;
	import std.range;

	final switch(m_mode) with(MODE) {
	case SIMPLE:
		m_files
			.filter!(a => a.exists)
			.map!(a => CoverageLoader(a))
			.chain(m_dirs.map!(a => a.openDir).joiner)
			.each!(a => a.coverage == float.infinity
				? writefln("%s has no code", a.sourceName)
				: writefln("%s is %.2f%% covered", a.sourceName, a.coverage));
			break;
	case SOURCE:
		m_files
			.filter!(a => a.exists)
			.map!(a => CoverageLoader(a))
			.chain(m_dirs.map!(a => a.openDir).joiner)
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
			.chain(m_dirs.map!(a => a.openDir).joiner)
			.filter!(a => a.coverage != float.infinity)
			.array
			.sort!((a, b) => a.coverage < b.coverage)
			.each!(a => m_verbose
			       ? writefln("%-40s | %-60s | %.2f%%", a.sourceName, a.resultName, a.coverage)
			       : writefln("%-40s | %.2f%%", a.sourceName, a.coverage));
	}
	return 0;
}
