import ae.utils.funopt;
import ae.utils.main;

import std.exception;
import std.random;
import std.stdio;
import std.string;

import dcaptcha.dcaptcha;

void printChallenge(Challenge challenge)
{
	writeln("Question:");
	writeln(challenge.question);
	writeln();
	writeln(challenge.code);
	writeln();
	writeln("Answers:");
	foreach (n, answer; challenge.answers)
		writeln(n+1, ". ", answer);
}

struct Test
{
static:
	@("Generate and print a sample CAPTCHA.")
	void gen(bool allowEasy, bool allowHard, bool allowStatic)
	{
		CaptchaSpec spec = { allowEasy : allowEasy, allowHard : allowHard, allowStatic : allowStatic };
		auto challenge = getCaptcha(spec);
		printChallenge(challenge);
	}

	@("Generate and validate random CAPTCHAs.")
	void test(bool verify)
	{
		rndGen.seed(0);

		while (true)
		{
			static int n; writeln(n++); stdout.flush();
			auto difficulty = uniform(0, 3);
			CaptchaSpec spec = CaptchaSpec(difficulty<=1, difficulty>=1, uniform(0, 2)==0);
			auto challenge = getCaptcha(spec);
			scope(failure) printChallenge(challenge);

			foreach (line; challenge.code.splitLines())
				enforce(line.length <= 38, "Line too long");

			if (verify && challenge.question == "What will be the return value of the following function?")
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
}

mixin main!(funoptDispatch!Test);
