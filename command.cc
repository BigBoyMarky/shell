
/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pwd.h>

#include "command.h"


#include "tty.h"

//extern char **environ;




SimpleCommand::SimpleCommand()
{
	// Creat available space for 5 arguments
	_numberOfAvailableArguments = 5;
	_numberOfArguments = 0;
	_arguments = (char **) malloc( _numberOfAvailableArguments * sizeof( char * ) );
}

void
SimpleCommand::insertArgument( char * argument )
{
	if ( _numberOfAvailableArguments == _numberOfArguments  + 1 ) {
		// Double the available space
		_numberOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				  _numberOfAvailableArguments * sizeof( char * ) );
	}

   // insert environment variables
    char* finalString = (char*)malloc(2048);
    if (strchr(argument, '$'))
    {
        int j = 0;
        int k = 0;
        while(argument[j] != '\0')
        {
            if (argument[j] == '$')
            {
                char* var = (char*)malloc(strlen(argument));
                j += 2;
                while(argument[j] != '}')
                {
                    var[k] = argument[j];
                    k++;
                    j++;
                }
                var[k] = '\0';
                strcat(finalString, getenv(var));
                free(var);
                k = 0;
            }
            else
            {
                char* temp = (char*)malloc(strlen(argument));
                while(argument[j] != '\0' && argument[j] != '$')
                {
                    temp[k] = argument[j];
                    k++;
                    j++;
                }
                k = 0;
                strcat(finalString, temp);
                free(temp);
                j--;
            }
            j++;
        }
        argument = strdup(finalString);
    }


    // tilde expansion
    if (argument[0] == '~') {

        if (strlen(argument) == 1) {

            argument = strdup(getenv("HOME"));

        } else {

            argument = strdup(getpwnam(argument+1)->pw_dir);

        }

    }



	_arguments[ _numberOfArguments ] = argument;

	// Add NULL argument at the end
	_arguments[ _numberOfArguments + 1] = NULL;

	_numberOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numberOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **)
		malloc( _numberOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
}

void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numberOfAvailableSimpleCommands == _numberOfSimpleCommands ) {
		_numberOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
			 _numberOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}

	_simpleCommands[ _numberOfSimpleCommands ] = simpleCommand;
	_numberOfSimpleCommands++;
}

void
Command:: clear()
{
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numberOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}

		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inputFile ) {
		free( _inputFile );
	}

	if ( _errFile ) {
		free( _errFile );
	}

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
}

void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");

	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numberOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inputFile?_inputFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO");
	printf( "\n\n" );

}

void
Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numberOfSimpleCommands == 0 ) {
		prompt();
		return;
	}

	int tempin = dup(0);
	int tempout = dup(1);
	int temperr = dup(2);

	int fdout;
	int fdin;
	int fderr;
	int ret;



	if (!strcmp(_simpleCommands[0]->_arguments[0], "exit")) {

		printf("Good bye!!\n");
		ttyteardown();
		exit(1);

	}

	if (!strcmp(_simpleCommands[0]->_arguments[0], "setenv")) {

    	if (setenv(_simpleCommands[0]->_arguments[1], _simpleCommands[0]->_arguments[2], 1)) {

    		perror("setenv");

    	}

        clear();
        prompt();
        return;

    }



    if (!strcmp(_simpleCommands[0]->_arguments[0], "unsetenv")) {

        if (unsetenv(_simpleCommands[0]->_arguments[1])) {

        	perror("unsetenv");

        }

        clear();
        prompt();
        return;

    }



   	if (strcmp(_simpleCommands[0]->_arguments[0], "cd") == 0)
    {
        char **p = environ;
        while(*p != NULL)
        {
            if (strncmp(*p, "HOME", 4) == 0)
            {
                break;
            }
            p++;
        }

        char *home = (char*)malloc(strlen(*p) - 5);
        strcpy(home, *p+5);

        int result;
        if (_simpleCommands[0]->_numberOfArguments > 1)
            result = chdir(_simpleCommands[0]->_arguments[1]);
        else
            result = chdir(home);

        if (result != 0)
            perror("chdir");

        clear();
        prompt();
        return;

    }

    else if (strcmp(_simpleCommands[0]->_arguments[0], "cd;") == 0) {

/*        char **p = environ;
        char *home = (char*)malloc(strlen(*p) - 5);
        strcpy(home, *p+5)
        int result;
            result = chdir(home);*/
        chdir(getenv("HOME"));


    }




	if (_inputFile) {

		fdin = open(_inputFile, O_RDWR, 0777);

	}

	else {

		fdin = dup(tempin);

	}

	if (_errFile) {

		if (_append == 1) {

			fderr = open(_outFile, O_APPEND|O_WRONLY, 0664);

		}

		else {

			fderr = open(_errFile, O_CREAT|O_WRONLY|O_TRUNC, 0777);

		}

		if (fderr < 0) {

			perror("open");
			exit(1);

		}

	}

	else {

		fderr = dup(tempout);

	}

	dup2(fderr, 2);


	for (int i = 0; i < _numberOfSimpleCommands; i++) {

		dup2(fdin,0);
		dup2(fderr,2);
		close(fdin);

		if (i == _numberOfSimpleCommands - 1) {




		if (_outFile) {

			if (_append == 1) {
			//	fprintf(stderr,"yes");

				fdout = open(_outFile, O_APPEND|O_WRONLY, 0664);

			}

			else {

				fdout = open(_outFile, O_CREAT|O_WRONLY|O_TRUNC, 0664);

			}

			if ( fdout < 0 ) {

				perror("open");
				exit(1);

			}

		}

		else {

			fdout = dup(tempout);

		}

			}

			else {

				int fdpipe[2];
				pipe(fdpipe);
				fdout=fdpipe[1];

			}

		dup2(fdout, 1);
		close(fdout);


		ret = fork();

		if (ret == 0)
        {
            /*if (strcmp(_simpleCommands[i]->_arguments[0], "printenv") == 0)
            {
                char **p = environ;

                while(*p != NULL)
                {
                    printf("%s\n", *p);
                    p++;
                }

                exit(0);
            }*/

            execvp(_simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments);
            perror(_simpleCommands[i]->_arguments[0]);

            _exit(1);
        }

		else if (ret < 0) {

			perror("fork");
			return;

		}

	} // end for

	dup2(tempin, 0);
	dup2(tempout, 1);
	dup2(temperr, 2);

	close(tempin);
	close(tempout);
	close(temperr);

	if (!_background) {

		// wait for last process
		waitpid(ret, 0, 0);

	}

	// Clear to prepare for next command
	clear();

	// Print new prompt
	prompt();

}

// Shell implementation

void
Command::prompt()
{
	if ( isatty(0) ) {

		printf("Shell>");
		fflush(stdout);

	}

}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;

int yyparse(void);



void killzombie(int sig)
{

	while(waitpid(-1, NULL, WNOHANG) > 0);

}



main()
{


ttyinit("", ".hist");




	struct sigaction signalAction;
    signalAction.sa_handler = killzombie;
    sigemptyset(&signalAction.sa_mask);
    signalAction.sa_flags = SA_RESTART;

    int error = sigaction(SIGCHLD, &signalAction, NULL);
    if ( error )
    {
        perror( "sigaction" );
        exit( -1 );
    }

	Command::_currentCommand.prompt();
	yyparse();

}

