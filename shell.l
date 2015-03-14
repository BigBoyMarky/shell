
/*
 *
 * CS-252 Spring 2015
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"
#include <sys/wait.h>

#include <unistd.h>



#include "tty.h"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

int ttygetc(FILE *f)
{
    static char *s = NULL;
    static char *lineBuf;

    char c;
    if (!isatty(0))
        return getc(f); // No need to use the line editor

    // If s is null, we need input. Grab it from the line editor.
    if (s == NULL)
    {
        lineBuf = ttygetline(TTY_MAX_LINEBUFFER);
        s = lineBuf;
    }

    c = *s++; // Read one character from our buffer
    if (!*s) // Check if we are at the end of the current line buffer
    {
        free(lineBuf);
        s = NULL;
    }

    // Return a char like getc would
    return c;
}
#undef getc
#define getc(f) ttygetc(f)

%}

%%

\n 	{
		return NEWLINE;
	}

[ \t] 	{
		/* Discard spaces and tabs */
     	}	

">" 	{
		return GREAT;
	}

">>" {
		return GREATGREAT; 
}

"|" {
		return PIPE;
}

"&" {
		return AMPERSAND;
}

"<" {
		return LESS;
}

">&" {
		return GREATAMPERSAND;
}

">>&" {
		return GREATGREATAMPERSAND;
}

\"[^\n"]*\" {
    
	yytext = (char*)(yytext + 1);
	yytext[strlen(yytext) - 1] = '\0';
	yylval.string_val = strdup(yytext);
	return WORD;

} 

`[^\n`]*` {
	
	//subshell
	
}

[^ \t\n&<>\|]*\\[^ \t\n]* {
	
	char *escapes = (char*)malloc(1024*sizeof(char));
	int j = 0;

	for(int i = 0; i < strlen(yytext); i++) {

		if(yytext[i] == '\\') {

			if(yytext[i + 1] == '\\') {

				escapes[j] = yytext[i + 1];
				i++; 
				j++;

			}
		}

		else {
			escapes[j] = yytext[i];
			j++;
		}

	}
	
	yylval.string_val = strdup(escapes);
	return WORD;
}


[^ ^\\&<>|\t\n][^ ^\\&<>|\t\n]*  {
	    yylval.string_val = strdup(yytext);
    	return WORD;
	}

.	{
		return NOTOKEN;
}
	
%%
