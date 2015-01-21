#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "header.h"
#include "symtab.h"

extern int yyparse();
extern FILE* yyin;

extern struct SymTable *symbolTable;
extern struct PType *funcReturn;
extern char fileName[256];

extern __BOOLEAN semError; 

int  main( int argc, char **argv )
{
	/*if( argc == 1 )
	{
		yyin = stdin;
	}
	else */if( argc == 2 )
	{
		FILE *fp = fopen( argv[1], "r" );
		if( fp == NULL ) {
				fprintf( stderr, "Open file error\n" );
				exit(-1);
		}
		yyin = fp;
        
        //handle output .j filename and open the file
        char tmp[256],*pch,*pch2;
        strcpy(tmp,argv[1]);
        pch = pch2 = strtok(tmp,"/");
        while(pch2!=NULL){
            pch  = pch2;
            pch2 = strtok(NULL,"/");
        }
        pch2 = strtok(pch,".");
        strcpy(filename,pch2);
        printf("%s\n",filename);

        strcat(pch2,".j");
        printf("%s\n",pch2);
        output = fopen(pch2,"w"); 

        //initial .j file
        fprintf(output,".class public %s\n",filename);
        fprintf(output,".super java/lang/Object\n");
        fprintf(output,".field public static _sc Ljava/util/Scanner;\n\n");
        
        //initial next_num
        next_num = 1;
        //initial ismain
        is_main = 0;
        //initial lable
        int i;
        for(i=0;i<50;++i)
            lable[i] = 1;
        //initial global init buf
        memset(global_init_buf,0,sizeof(global_init_buf));
	}
	else
	{
	  	fprintf( stderr, "Usage: ./parser [filename]\n" );
   		exit(0);
 	} 

	symbolTable = (struct SymTable *)malloc(sizeof(struct SymTable));
	initSymTab( symbolTable );

	// initial function return recoder

	yyparse();	/* primary procedure of parser */

	if(semError == __TRUE){	
		fprintf( stdout, "\n|--------------------------------|\n" );
		fprintf( stdout, "|  There is no syntactic error!  |\n" );
		fprintf( stdout, "|--------------------------------|\n" );
	}
	else{
		fprintf( stdout, "\n|-------------------------------------------|\n" );
		fprintf( stdout, "| There is no syntactic and semantic error! |\n" );
		fprintf( stdout, "|-------------------------------------------|\n" );
	}

	exit(0);
}

