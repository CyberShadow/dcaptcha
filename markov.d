module dcaptcha.markov;

import std.algorithm;
import std.array;
import std.exception;

import ae.utils.array;

immutable sourceText = import("alice30.txt");

template MarkovChain(int LENGTH)
{
	immutable static string[][string[]] dictionary;

	shared static this()
	{
		auto paragraphs =
			sourceText
			.split("\n\n")
			.map!(paragraph => paragraph
				.replace("\n", " ")
				.split()
				.assumeUnique()
			)
			.array();

		string[][string[]] dic;
		foreach (paragraph; paragraphs)
			foreach (int n; 0..paragraph.length)
				dic[paragraph[max(n-LENGTH, 0)..n]] ~= paragraph[n];
		dictionary = dic.assumeUnique();
	}

	string[] query()
	{
		string[] tail, result;
		immutable(string[])* p;
		while ((p = tail in dictionary) !is null)
		{
			result ~= (*p).sample;
			tail = result[max(cast(int)$-LENGTH, 0)..$];
		}
		return result;
	}
}

version(markov_main)
void main()
{
	import std.stdio;
	writeln(MarkovChain!2.query().join(" "));
}
