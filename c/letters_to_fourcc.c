#include <stdio.h>
#include <stdlib.h>

int main(int argc, char* argv[]) {
	char a = argv[1][0];
	char b = argv[1][1];
	char c = argv[1][2];
	char d = argv[1][3];

	unsigned int f = ((uint)(a) | ((uint)(b) << 8) | ((uint)(c) << 16) | ((uint)(d) << 24));
	printf("%d (0x%x)\n", f, f);
	return 0;
}

