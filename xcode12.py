import os, fnmatch

pattern = "// ignore-xcode-12"

def commentOut(n):

	if pattern in n:
		return "// %s" % (n)

	return n

def find(directory, filePattern):
	for path, dirs, files in os.walk(os.path.abspath(directory)):
		for filename in fnmatch.filter(files, filePattern):
			filepath = os.path.join(path, filename)
			with open(filepath) as f:
				s = f.read()
			if pattern in s:
				lines = s.split("\n")
				s = '\n'.join(list(map(commentOut, lines)))
				with open(filepath, "w") as f:
					f.write(s)


find("./Sources", "*.swift")
