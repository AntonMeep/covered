module covered.loader;

import std.array : array;
import std.algorithm : map, each, filter, canFind, until, find, stripLeft;
import std.conv : to;
import std.range : drop, tee, isInputRange, ElementType;
import std.regex : matchFirst, regex;
import std.stdio : File;
import std.typecons : Tuple, tuple;

auto openFilesDirs(string[] files, string[] dirs) {
	import std.algorithm : joiner;
	import std.file : exists, dirEntries, SpanMode;
	import std.range : chain;
	return files
		.chain(dirs
			.map!(a => a.dirEntries("[!.]*.lst", SpanMode.shallow))
			.joiner)
		.filter!(a => a.exists);
}

deprecated("Use openFilesDirs instead") auto openDir(string name) {
	import std.file : exists, dirEntries, SpanMode;

	assert(name.exists);

	return name.dirEntries("[!.]*.lst", SpanMode.shallow)
		.map!(a => CoverageLoader(File(a.name, "r")));
}

alias Line = Tuple!(
	bool, "used", // True, if this line contains executable code and used in code coverage analysis
	size_t, "count", // How many times this line is executed. 0, if `used` == `false`
	dchar[], "source" // Line text
);

auto loadCoverage(string f) {
	return CoverageLoader(f);
}

struct CoverageLoader {
	private {
		File m_file;
		Line[] m_source;
		dchar[] m_sourcename;
		float m_coverage;
	}

	this(string f) { this(File(f, "r")); }

	this(File f) {
		m_file = f;

		m_source = m_file.byLine!(char, dchar)
			.tee!((a) {
				if(!a.canFind('|') && !m_sourcename.length) {
					auto m = a.matchFirst(regex(r"(.+\.d) (?:(?:is \d+% covered)|(?:has no code))"d));
					if(m.empty)
						return;
					m_sourcename = m[1];
				}
			})
			.filter!(a => a.canFind('|'))
			.map!(a =>
				tuple!("used", "count", "source")(
					a.until('|').canFind!(x => x != ' '),
					a
						.until('|')
						.stripLeft(' ')
						.toNumber,
					a.find('|').drop(1).array
				)
			)
			.array;

		size_t covered, total;
		m_source
			.filter!(a => a.used)
			.tee!(a => a.count != 0 ? ++covered : 0)
			.each!(a => ++total);

		if(covered == 0 && total == 0) {
			m_coverage = float.infinity;
		} else {
			m_coverage = covered.to!float / total.to!float * 100.0;
		}
	}

	// Name of parsed file (*.lst)
	auto resultName() { return m_file.name; }

	// Name of source file (*.d)
	dchar[] sourceName() { return m_sourcename; }

	// File source
	Line[] source() { return m_source; }

	// Code coverage. `float.infinity`, if there is no executable code
	float coverage() { return m_coverage; }
}

private size_t toNumber(T)(T inp)
if(isInputRange!T && is(ElementType!T == dchar)) {
	auto temp = inp.array;
	if(temp.length) {
		return temp.to!size_t;
	} else {
		return 0;
	}
}
