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

struct CoverageLoader2 {
	private {
		File m_file;
		char[] m_buffer;

		bool m_coverage_computed = false;
		float m_coverage;

		bool m_stats_available = 0;

		size_t m_covered;
		size_t m_total;
	}

	this(string fname) { this(File(fname, "r")); }

	this(File f) {
		m_file = f;
	}

	ByEntryRange byEntry() { return ByEntryRange(m_file); }

	private void getCoveredAndTotalLines() {
		import std.string : indexOf, stripLeft;
		import std.conv : to;

		m_buffer.reserve(4096);

		m_covered = m_total = 0;
		import std.stdio;
		import std.experimental.logger;

		while(m_file.readln(m_buffer)) {
			immutable bar = m_buffer.indexOf('|');

			if(bar == -1) {
				break;
			} else {
				auto num = m_buffer[0..bar].stripLeft;
				if(num.length) {
					foreach(ref c; num) {
						if(c != '0') {
							++m_covered;
							break;
						}
					}
					++m_total;
				}
			}
		}

		m_stats_available = true;
	}

	size_t getTotalCount() {
		if(!m_stats_available)
			this.getCoveredAndTotalLines();

		return m_total;
	}

	size_t getCoveredCount() {
		if(!m_stats_available)
			this.getCoveredAndTotalLines();

		return m_covered;
	}

	float getCoverage() {
		if(!m_stats_available)
			this.getCoveredAndTotalLines();

		if(!m_coverage_computed)
			m_coverage = m_covered.to!float / m_total.to!float * 100.0f;

		return m_coverage;
	}
}

@(".getCoveredCount, .getTotalCount and .getCoverage produce expected results")
unittest {
	auto c = CoverageLoader2("sample/hello.lst");
	c.getCoveredCount.should.be.equal(1);
	c.getTotalCount.should.be.equal(1);

	c.getCoverage.should.be.equal(100.0f);
}

struct Entry {
	bool Used;
	size_t Count;
	string Source;
}

struct ByEntryRange {
	private {
		File m_file;
		Entry m_last;
		bool m_empty;
		char[] m_buffer;
	}

	this(File f) {
		m_buffer.reserve(4096);
		m_file = f;
		this.popFront;
	}

	@property Entry front() { return m_last; }
	@property bool empty() { return m_empty; }

	void popFront() {
		import std.string : indexOf, stripLeft;
		import std.conv : to;
		immutable read = m_file.readln(m_buffer);
		if(read == 0) {
			m_empty = true;
			return;
		} else {
			immutable bar = m_buffer[0..read].indexOf('|');

			if(bar == -1) {
				m_empty = true;
				return;
			} else {
				auto num = m_buffer[0..bar].stripLeft;
				if(num.length) {
					m_last.Used = true;
					m_last.Count = num.to!size_t;
				} else {
					m_last.Used = false;
					m_last.Count = 0;
				}

				m_last.Source = m_buffer[bar + 1 .. read].dup;
			}
		}
	}
}

version(unittest) import fluent.asserts;

@("ByElementRange produces expected results")
unittest {
	import std.array : array;

	ByEntryRange(File("sample/hello.lst" ,"r")).array
		.should.be.equal([
			Entry(false, 0, "import std.stdio;\n"),
			Entry(false, 0, "\n"),
			Entry(false, 0, "void main() {\n"),
			Entry(true, 1, "        writeln(\"Hello world!\");\n"),
			Entry(false, 0, "}\n"),
		]);
}
