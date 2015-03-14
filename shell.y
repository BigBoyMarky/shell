
/*
 * CS-252 Spring 2015
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * You must extend it to understand the complete shell grammar.
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE GREATGREAT PIPE AMPERSAND LESS GREATAMPERSAND GREATGREATAMPERSAND

%union	{
		char   *string_val;
	}

%{
//#define yylex yylex


#include <stdio.h>
#include <string.h>
#include "command.h"
#include <stdlib.h>
#include <regex.h>
#include <dirent.h>

#define MAXFILENAME 1024

int maxEntries = 20;


void yyerror(const char * s);
int yylex();

int compare(const void *a, const void *b) 
{ 
    const char **ia = (const char **)a;
    const char **ib = (const char **)b;
    return strcmp(*ia, *ib);
  
}

void expandWildcard(char * prefix, char * suffix) {
//	printf("prefix %s\n",prefix );
//	printf("suffix %s\n",suffix );
char** array = (char**) malloc(maxEntries*sizeof(char*));
int nEntries = 0;
	if (suffix[0] == 0) {

		Command::_currentSimpleCommand->insertArgument(strdup(prefix));
		return;

	}







	char * s = strchr(suffix, '/');
	char component[MAXFILENAME];


/*	if (suffix[0] == '/') {
		
		s = strchr((char*)(suffix+1), '/');
//		printf("if dif: %d\n", s-suffix);
		suffix=s+1;

	} 
	else */if ( s != NULL ) {	

		strncpy(component, suffix, s-suffix);
//		printf("else if dif: %d\n", s-suffix);
component[s-suffix] = '\0';
		suffix = s+1;

//		strcat(component, "\0");

	}

	else {

		strcpy(component, suffix);
		suffix = suffix + strlen(suffix);
		strcat(component, "\0");

	}
	
	// Now we need to expand the component
	char newPrefix[MAXFILENAME];

	if (strchr(component, '*') == NULL && strchr(component, '?') == NULL) {

    	// component does not have wildcards
		//printf("PREFIX: %s", prefix);
		//printf("COMPONENT: %s", component);
		if(prefix[0] == '/' && prefix[1] == '\0')
			//if (prefix[1] == '\0')
			sprintf(newPrefix, "%s%s", prefix, component);
		else
	    	sprintf(newPrefix, "%s/%s", prefix, component);

	//	printf("Prefix:%s\nComponent:%s\nnewPrefix:%s\n", prefix, component, newPrefix);

	    expandWildcard(newPrefix, suffix);
	    return;

	}

	char * reg = (char*)malloc(2*strlen(component)+10);	
	char * a = component;
	char * r = reg;

	*r = '^'; 
	r++;

	while (*a) {
		if (*a == '*') { 
			*r = '.'; r++; *r = '*'; r++; 
		}
		else if (*a == '?') { 
			*r = '.'; r++; 
		}
		else if (*a == '.') {
			*r = '\\'; r++; *r = '.'; r++; 
		}
		else { 
			*r = *a; r++; 
		}
		a++;
	}
	

	*r='$';
	r++;
	*r=0;




	regex_t tempreg;
	int tempregret;

	tempregret = regcomp(&tempreg, reg, 0);

	if (tempregret) {

		perror("compile");
		return;

	}



	// If prefix is empty then list current directory
	
	char* dir;
	if (prefix == "") {

		const char * period = ".";
		dir = strdup(period);

	}
	
	else {

		dir = prefix;

	}

	DIR * d = opendir(dir); 

	if (d == NULL) {
//printf("ifsadfjongvoangvlksgnalgnaoriskdlj");
		return;

	}



//printf("post opendir\n");


	// Now we need to check what entries match
	struct dirent * ent;
	regmatch_t match;
	while ((ent=readdir(d)) != NULL) {

		// Check if name matches
		if (regexec(&tempreg, ent->d_name, 1, &match, 0) == 0) {

			if (nEntries == maxEntries) {

				maxEntries *=2;
				array = (char**)realloc(array, maxEntries*sizeof(char*));

			}
//printf("asfd\n");
			if(ent->d_name[0] == '.') {

				if(component[0] == '.')	{

					if(prefix == "") {

							sprintf(newPrefix, "%s%s", prefix,  ent->d_name);
							
					array[nEntries] = strdup(newPrefix);
					nEntries++;

					}

			
					//expandWildcard(newPrefix,suffix);

				}

			}

			else {





				if (prefix[0] == '/' && prefix[1] == '\0'){
					sprintf(newPrefix, "%s%s", prefix, ent->d_name);
					array[nEntries++] =strdup(newPrefix);
					}
				
				else if(prefix[0] =='\0') {
					sprintf(newPrefix, "%s%s", prefix,  ent->d_name);

					//printf("prefix:%s\nentdname:%s\nnewPrefix:%s\n", prefix, ent->d_name, newPrefix);

					array[nEntries] = strdup(newPrefix);
					nEntries++;
				}
				else {
					sprintf(newPrefix, "%s/%s", prefix, ent->d_name);

					//printf("prefix:%s\nentdname:%s\nnewPrefix:%s\n", prefix, ent->d_name, newPrefix);

					array[nEntries] = strdup(newPrefix);
					nEntries++;
				}


		/*		if (prefix == "" || prefix[0] == 0) {

					sprintf(newPrefix, "%s", ent->d_name);
					array[nEntries] = strdup(ent->d_name);
					nEntries++;

				} else {
	 
					sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
					array[nEntries] = strdup(ent->d_name);
					nEntries++;

				}
*/
			}


		}

	}

	closedir(d);

	qsort(array, nEntries, sizeof(char*), compare);

	for (int i = 0; i < nEntries; i++) {

		expandWildcard(array[i], suffix);

	}
nEntries = 0;
	free(array);

}

%}

%%

goal:	
	commands
	;

commands: 
	command
	| commands command
	;

command: simple_command
        ;

simple_command:	
	pipe_list iomodifier_list background_opt NEWLINE {
		//printf("   Yacc: Execute command\n");
			//Command::_currentCommand.print();
		Command::_currentCommand.execute();
	}
	| NEWLINE {
		Command::_currentCommand.prompt();
	}
	| error NEWLINE { yyerrok; }
	;

pipe_list:
		 pipe_list PIPE command_and_args
		 | command_and_args
		 ;

command_and_args:
	command_word arg_list {
		Command::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
	}
	;

arg_list:
	arg_list argument
	| /* can be empty */
	;

argument:
	WORD {
               //printf("   Yacc: insert argument \"%s\"\n", $1);

			if (strchr($1, '*') == NULL && strchr($1, '?') == NULL) {
				Command::_currentSimpleCommand->insertArgument( $1 );
			}
			else {
				expandWildcard("", $1);
			}

	}
	;

command_word:
	WORD {
               //printf("   Yacc: insert command \"%s\"\n", $1);
	       
	       Command::_currentSimpleCommand = new SimpleCommand();
	       Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_opt:
	GREAT WORD {
		
		if (Command::_currentCommand._outFile)
			{
				fprintf(stdout,"Ambiguous output redirect\n");
				exit(0);
				}
		//printf("   Yacc: insert output \"%s\"\n", $2);
		Command::_currentCommand._outFile = $2;
	}
	| GREATGREAT WORD {
		
		if (Command::_currentCommand._outFile) {
			fprintf(stdout, "Ambiguous output redirect\n");
			exit(0);
			}
		//printf("   Yacc: append output \"%s\"\n", $2);
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._append = 1;
	}
	| LESS WORD {
		//printf("   Yacc: redirect input \"%s\"\n",. $2);
		Command::_currentCommand._inputFile = $2;
	}
	| GREATAMPERSAND WORD {
		
		if (Command::_currentCommand._outFile) {
			fprintf(stdout, "Ambiguous output redirect\n");
			exit(0);
			}
		Command::_currentCommand._outFile = strdup($2);
		Command::_currentCommand._errFile = $2;
	}
	| GREATGREATAMPERSAND WORD {

		if(Command::_currentCommand._outFile) {
			fprintf(stdout, "Ambiguous output redirect\n");
			exit(0);
			}
//		Command::_currentCommand._append = 1;
//		Command::_currentCommand._outFile = strdup($2);
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = $2;
		Command::_currentCommand._append = 1;
	}
	
	;

iomodifier_list:
	iomodifier_list iomodifier_opt
	| iomodifier_opt
	| /* empty */
	;

background_opt:
	AMPERSAND
	{
	Command::_currentCommand._background = 1;
	}
	| /* empty */
	;

%%

void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
