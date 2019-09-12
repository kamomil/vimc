#include <stdlib.h>
#include <stdio.h>

int main(int argc, char* argv[]) {

	unsigned f = atoi(argv[1]);
	char a = f & 0x000000ff;
	char b = (f & 0x0000ff00) >> 8;
	char c = (f & 0x00ff0000) >> 16;
	char d = (f & 0xff000000) >> 24;
	printf("%u\n",f);
	printf("%c %c %c %c\n",a,b,c,d);
	return 0;
}
