/// A CAPTCHA generator for D services.
/// Written in the D programming language.

module dcaptcha.dcaptcha;

import std.algorithm;
import std.conv;
import std.exception;
import std.random;
import std.range;
import std.string;

import ae.utils.array;

import dcaptcha.markov;

struct Challenge
{
	string question, code;
	string[] answers;
	string hint; /// HTML!
}

/**
	Goals:
	- Answers should not be obvious:
	  - Keywords shouldn't give away the answer, e.g. `unittest { ... }`
	    is obviously an unit test block.
	  - `return 2+2` is obvious to non-programmers.
	- Answers should vary considerably:
	  - A question which has the answer "0" much of the time is easy
	    to defeat simply by giving the answer "0" all of the time.
	- Questions should not be Google-able:
	  - Search engines ignore most punctuation and math operators.
	  - Keywords and string literals should vary or be generic enough.
**/

Challenge getCaptcha()
{
	string[] identifiers =
		26
		.iota
		.map!(l => [cast(char)('a'+l)].assumeUnique())
		.filter!(s => s != "l")
		.array();
	identifiers ~= "foo, bar, baz".split(", ");
	//identifiers ~= "qux, quux, corge, grault, garply, waldo, fred, plugh, xyzzy, thud".split(", ");

	string[] mathOperators = "+ - / * %".split();

	Challenge challenge;
	with (challenge)
		[
			// Calculate function result
			// (use syntax that only programmers should be familiar with)
			{
				question = "What will be the return value of the following function?";
				hint = `You can run D code online on <a href="http://dpaste.dzfl.pl/">DPaste</a>.`;
				[
					// Modulo operator (%)
					{
						int x, y;
						do
						{
							x = uniform(10, 50);
							y = uniform(x/4, x/2);
						}
						while (x % y == 0);

						code =
							q{
								int F()
								{
									int A = X;
									A %= Y;
									return A;
								}
							}.formatExample()
							.replace("F", identifiers.pluck)
							.replace("A", identifiers.pluck)
							.replace("X", x.text)
							.replace("Y", y.text)
						;
						answers = [(x % y).text];
					},
					// Integer division, increment
					{
						int y = uniform(2, 5);
						int x = uniform(5, 50/y) * y + uniform(1, y);
						int sign = uniform(0, 2) ? -1 : 1;
						code =
							q{
								int F()
								{
									int A = X, B = Y;
									B@@;
									A /= B;
									return A;
								}
							}.formatExample()
							.replace("F", identifiers.pluck)
							.replace("A", identifiers.pluck)
							.replace("B", identifiers.pluck)
							.replace("X", x.text)
							.replace("Y", (y - sign).text)
							.replace("@", sign > 0 ? "+" : "-")
						;
						answers = [(x / y).text];
					},
				].sample()();
			},
		].sample()();
	return challenge;
}

private string[] cartesianJoin(PARTS...)(PARTS parts)
{
	return cartesianProduct(parts).map!(t => join([t.expand])).array();
}

private string formatExample(string s)
{
	return s
		.outdent()
		.strip()
		.replace("\t", "  ")
	;
}

private void printChallenge()(Challenge challenge)
{
	import std.stdio;
	writeln("Question:");
	writeln(challenge.question);
	writeln();
	writeln(challenge.code);
	writeln();
	writeln("Answers:");
	foreach (n, answer; challenge.answers)
		writeln(n+1, ". ", answer);
}

version(dcaptcha_main)
void main()
{
	auto challenge = getCaptcha();
	printChallenge(challenge);
}

version(dcaptcha_test)
void main()
{
	import std.stdio;
	while (true)
	{
		static int n; writeln(n++); stdout.flush();
		auto challenge = getCaptcha();
		scope(failure) printChallenge(challenge);

		foreach (line; challenge.code.splitLines())
			enforce(line.length <= 38, "Line too long");

		version(dcaptcha_verify)
		if (challenge.question == "What will be the return value of the following function?")
		{
			auto functionName = challenge.code.split()[1];
			auto expr = "(){ " ~ challenge.code.replace("\n", " ") ~ " writeln(" ~ functionName ~ "); }()";
			import std.process;
			auto result = execute(["rdmd", "--eval=" ~ expr]);
			scope(failure) writeln("rdmd output: ", result.output);
			enforce(result.status == 0, "rdmd failed");
			enforce(result.output.strip() == challenge.answers[0], "Wrong answer");
		}

		enforce(challenge.answers[0] != "0", "Zero answer");
	}
}
