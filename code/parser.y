%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "header.h"
#include "symtab.h"
#include "semcheck.h"

extern int linenum;
extern FILE	*yyin;
extern char	*yytext;
extern char buf[256];
extern int Opt_Symbol;		/* declared in lex.l */

int scope = 0;
char fileName[256];
struct SymTable *symbolTable;
__BOOLEAN paramError;
struct PType *funcReturn;
__BOOLEAN semError = __FALSE;
int inloop = 0;

%}

%union {
	int intVal;
	float floatVal;	
	char *lexeme;
	struct idNode_sem *id;
	struct ConstAttr *constVal;
	struct PType *ptype;
	struct param_sem *par;
	struct expr_sem *exprs;
	struct expr_sem_node *exprNode;
	struct constParam *constNode;
	struct varDeclParam* varDeclNode;
};

%token	LE_OP NE_OP GE_OP EQ_OP AND_OP OR_OP
%token	READ BOOLEAN WHILE DO IF ELSE TRUE FALSE FOR INT PRINT BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN CONST
%token	L_PAREN R_PAREN COMMA SEMICOLON ML_BRACE MR_BRACE L_BRACE R_BRACE ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP ASSIGN_OP LT_OP GT_OP NOT_OP

%token <lexeme>ID
%token <intVal>INT_CONST 
%token <floatVal>FLOAT_CONST
%token <floatVal>SCIENTIFIC
%token <lexeme>STR_CONST

%type<ptype> scalar_type
%type<par> parameter_list
%type<constVal> literal_const
%type<constNode> const_list 
%type<exprs> variable_reference logical_expression logical_term logical_factor relation_expression arithmetic_expression term factor logical_expression_list literal_list
%type<intVal> relation_operator add_op mul_op
%type<varDeclNode> identifier_list


%start program
%%

program :		decl_list 
			    funct_def
				decl_and_def_list 
				{
					if(Opt_Symbol == 1)
					printSymTable( symbolTable, scope );	
				}
		;

decl_list : decl_list var_decl
		  | decl_list const_decl
		  | decl_list funct_decl
		  |
		  ;


decl_and_def_list : decl_and_def_list var_decl
				  | decl_and_def_list const_decl
				  | decl_and_def_list funct_decl
				  | decl_and_def_list funct_def
				  | 
				  ;

		  
funct_def : scalar_type ID L_PAREN R_PAREN 
			{
				funcReturn = $1; 
				struct SymNode *node;
				node = findFuncDeclaration( symbolTable, $2 );
				
				if( node != 0 ){
					verifyFuncDeclaration( symbolTable, 0, $1, node );
				}
				else{
					insertFuncIntoSymTable( symbolTable, $2, 0, $1, scope, __TRUE );
				}

                if(strcmp($2,"main")!=0){
                    fprintf(output,".method public static %s()",$2); //TODO func name
                    switch( $1->type ) { 
                        case  INTEGER_t: 
                            fprintf(output,"I");
                            break;
                        case BOOLEAN_t:
                            fprintf(output,"Z");
                            break;
                        case FLOAT_t:
                            fprintf(output,"F");
                            break;
                        case DOUBLE_t:
                            fprintf(output,"D");
                    }
                    fprintf(output,"\n");
                    fprintf(output,".limit stack 30\n");
                    fprintf(output,".limit locals 30\n");
                }
                else{ //main func
                    is_main = 1;
                    fprintf(output,".method public static main([Ljava/lang/String;)V\n");
                    fprintf(output,".limit stack 30\n");
                    fprintf(output,".limit locals 30\n");
                    fprintf(output,"\tnew java/util/Scanner\n");
                    fprintf(output,"\tdup\n");
                    fprintf(output,"\tgetstatic java/lang/System/in Ljava/io/InputStream;\n");
                    fprintf(output,"\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
                    fprintf(output,"\tputstatic %s/_sc Ljava/util/Scanner;\n\n",filename);
                }
                
                //initial next_num
                next_num = 1;
			}
			compound_statement { is_main = 0; funcReturn = 0; fprintf(output,".end method\n\n"); next_num = 0; }	
		  | scalar_type ID L_PAREN parameter_list R_PAREN  
			{				
				funcReturn = $1;
				
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;
				}
				// check and insert function into symbol table
				else{
					struct SymNode *node;
					node = findFuncDeclaration( symbolTable, $2 );

					if( node != 0 ){
						if(verifyFuncDeclaration( symbolTable, $4, $1, node ) == __TRUE){	
							insertParamIntoSymTable( symbolTable, $4, scope+1 );
						}				
					}
					else{
						insertParamIntoSymTable( symbolTable, $4, scope+1 );				
						insertFuncIntoSymTable( symbolTable, $2, $4, $1, scope, __TRUE );
					}
				}
                //generate IR func decl
                fprintf(output,".method public static %s(",$2); //TODO func name
        		struct param_sem *parPtr;		
                for( parPtr=$4 ; parPtr!=0 ; parPtr=(parPtr->next) ) {			
                    switch( parPtr->pType->type ) { 
                        case  INTEGER_t: 
                            fprintf(output,"I");
                            break;
                        case BOOLEAN_t:
                            fprintf(output,"Z");
                            break;
                        case FLOAT_t:
                            fprintf(output,"F");
                            break;
                        case DOUBLE_t:
                            fprintf(output,"D");
                    }		
                }
                fprintf(output,")");
                switch( $1->type ) { 
                    case  INTEGER_t: 
                        fprintf(output,"I");
                        break;
                    case BOOLEAN_t:
                        fprintf(output,"Z");
                        break;
                    case FLOAT_t:
                        fprintf(output,"F");
                        break;
                    case DOUBLE_t:
                        fprintf(output,"D");
                }
                fprintf(output,"\n");
                fprintf(output,".limit stack 30\n");
                fprintf(output,".limit locals 30\n");
			} 	
			compound_statement { funcReturn = 0; fprintf(output,".end method\n\n"); next_num = 0; }
		  | VOID ID L_PAREN R_PAREN 
			{
				funcReturn = createPType(VOID_t); 
				struct SymNode *node;
				node = findFuncDeclaration( symbolTable, $2 );

				if( node != 0 ){
					verifyFuncDeclaration( symbolTable, 0, createPType( VOID_t ), node );					
				}
				else{
					insertFuncIntoSymTable( symbolTable, $2, 0, createPType( VOID_t ), scope, __TRUE );	
				}

                if(strcmp($2,"main")!=0)
                    fprintf(output,".method public static %s()V\n",$2); //TODO func name
                else //main func
                    fprintf(output,".method public static main([Ljava/lang/String;)V\n");
                fprintf(output,".limit stack 30\n");
                fprintf(output,".limit locals 30\n");
                if(strcmp($2,"main")==0){
                    fprintf(output,"\tnew java/util/Scanner\n");
                    fprintf(output,"\tdup\n");
                    fprintf(output,"\tgetstatic java/lang/System/in Ljava/io/InputStream;\n");
                    fprintf(output,"\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
                    fprintf(output,"\tputstatic %s/_sc Ljava/util/Scanner;\n\n",filename);
                    next_num = 0;
                }
			}
			compound_statement { funcReturn = 0; fprintf(output,"\treturn\n.end method\n\n"); next_num = 0; }	
		  | VOID ID L_PAREN parameter_list R_PAREN
			{									
				funcReturn = createPType(VOID_t);
				
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;
				}
				// check and insert function into symbol table
				else{
					struct SymNode *node;
					node = findFuncDeclaration( symbolTable, $2 );

					if( node != 0 ){
						if(verifyFuncDeclaration( symbolTable, $4, createPType( VOID_t ), node ) == __TRUE){	
							insertParamIntoSymTable( symbolTable, $4, scope+1 );				
						}
					}
					else{
						insertParamIntoSymTable( symbolTable, $4, scope+1 );				
						insertFuncIntoSymTable( symbolTable, $2, $4, createPType( VOID_t ), scope, __TRUE );
					}
				}

                //generate IR func decl
                fprintf(output,".method public static %s(",$2); //TODO func name
        		struct param_sem *parPtr;		
                for( parPtr=$4 ; parPtr!=0 ; parPtr=(parPtr->next) ) {			
                    switch( parPtr->pType->type ) { 
                        case  INTEGER_t: 
                            fprintf(output,"I");
                            break;
                        case BOOLEAN_t:
                            fprintf(output,"Z");
                            break;
                        case FLOAT_t:
                            fprintf(output,"F");
                            break;
                        case DOUBLE_t:
                            fprintf(output,"D");
                    }		
                }
                fprintf(output,")V\n");
                fprintf(output,".limit stack 30\n");
                fprintf(output,".limit locals 30\n");
                

			} 
			compound_statement { funcReturn = 0; fprintf(output,"\treturn\n.end method\n\n"); next_num = 0; }		  
		  ;

funct_decl : scalar_type ID L_PAREN R_PAREN SEMICOLON
			{
				insertFuncIntoSymTable( symbolTable, $2, 0, $1, scope, __FALSE );	
			}
		   | scalar_type ID L_PAREN parameter_list R_PAREN SEMICOLON
		    {
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;
				}
				else {
					insertFuncIntoSymTable( symbolTable, $2, $4, $1, scope, __FALSE );
				}
			}
		   | VOID ID L_PAREN R_PAREN SEMICOLON
			{				
				insertFuncIntoSymTable( symbolTable, $2, 0, createPType( VOID_t ), scope, __FALSE );
			}
		   | VOID ID L_PAREN parameter_list R_PAREN SEMICOLON
			{
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;	
				}
				else {
					insertFuncIntoSymTable( symbolTable, $2, $4, createPType( VOID_t ), scope, __FALSE );
				}
			}
		   ;

parameter_list : parameter_list COMMA scalar_type ID
			   {
				struct param_sem *ptr;
				ptr = createParam( createIdList( $4 ), $3 );
				param_sem_addParam( $1, ptr );
				$$ = $1;
			   }
			   | scalar_type ID { $$ = createParam( createIdList( $2 ), $1 ); }
			   ;

var_decl : scalar_type identifier_list SEMICOLON
			{
				struct varDeclParam *ptr;
				struct SymNode *newNode;
                char tmp_output[80][80],tmp_cat[80];
                int p=0,i;
				for( ptr=$2 ; ptr!=0 ; ptr=(ptr->next) ) {						
					if( verifyRedeclaration( symbolTable, ptr->para->idlist->value, scope ) == __FALSE ) { }
					else {
						if( verifyVarInitValue( $1, ptr, symbolTable, scope ) ==  __TRUE ){	
							newNode = createVarNode( ptr->para->idlist->value, scope, ptr->para->pType );
							insertTab( symbolTable, newNode );											
                            //var initial
                            if(ptr->isInit==__TRUE){
                                if(scope > 0){
                                    switch(ptr->para->pType->type){
                                        case  INTEGER_t: 
                                            sprintf(tmp_output[p++],"\tistore %d\n",next_num-1);
                                            break;
                                        case BOOLEAN_t:
                                            sprintf(tmp_output[p++],"\tistore %d\n",next_num-1);
                                            break;
                                        case FLOAT_t:
                                            sprintf(tmp_output[p++],"\tfstore %d\n",next_num-1);
                                            break;
                                        case DOUBLE_t:
                                            sprintf(tmp_output[p++],"\tdstore %d\n",next_num-1);
                                    }
                                }
                                else{   //global value
                                    sprintf(tmp_output[p],"\tputstatic %s/%s ",filename,ptr->para->idlist->value);
                                    switch(ptr->para->pType->type){
                                        case  INTEGER_t: 
                                            sprintf(tmp_cat,"I\n");
                                            break;
                                        case BOOLEAN_t:
                                            sprintf(tmp_cat,"I\n");
                                            break;
                                        case FLOAT_t:
                                            sprintf(tmp_cat,"F\n");
                                            break;
                                        case DOUBLE_t:
                                            sprintf(tmp_cat,"D\n");
                                    }
                                    strcat(tmp_output[p],tmp_cat);
                                    ++p;
                                }
                            }
						}
					}
				}
                for(i=p-1;i>=0;--i)
                    fprintf(output,"%s",tmp_output[i]);
			}
			;

identifier_list : identifier_list COMMA ID
				{					
					struct param_sem *ptr;	
					struct varDeclParam *vptr;				
					ptr = createParam( createIdList( $3 ), createPType( VOID_t ) );
					vptr = createVarDeclParam( ptr, 0 );	
					addVarDeclParam( $1, vptr );
					$$ = $1; 					
				}
                | identifier_list COMMA ID ASSIGN_OP logical_expression
				{
					struct param_sem *ptr;	
					struct varDeclParam *vptr;				
					ptr = createParam( createIdList( $3 ), createPType( VOID_t ) );
					vptr = createVarDeclParam( ptr, $5 );
					vptr->isArray = __TRUE;
					vptr->isInit = __TRUE;	
					addVarDeclParam( $1, vptr );	
					$$ = $1;
					
				}
                | ID ASSIGN_OP logical_expression
				{
					struct param_sem *ptr;					
					ptr = createParam( createIdList( $1 ), createPType( VOID_t ) );
					$$ = createVarDeclParam( ptr, $3 );		
					$$->isInit = __TRUE;
				}
                | ID 
				{
					struct param_sem *ptr;					
					ptr = createParam( createIdList( $1 ), createPType( VOID_t ) );
					$$ = createVarDeclParam( ptr, 0 );				
				}
                ;
		 
literal_list : literal_list COMMA logical_expression
				{
					struct expr_sem *ptr;
					for( ptr=$1; (ptr->next)!=0; ptr=(ptr->next) );				
					ptr->next = $3;
					$$ = $1;
				}
             | logical_expression
				{
					$$ = $1;
				}
             |
             ;

const_decl 	: CONST scalar_type const_list SEMICOLON
			{
				struct SymNode *newNode;				
				struct constParam *ptr;
				for( ptr=$3; ptr!=0; ptr=(ptr->next) ){
					if( verifyRedeclaration( symbolTable, ptr->name, scope ) == __TRUE ){//no redeclare
						if( ptr->value->category != $2->type ){//type different
							if( !(($2->type==FLOAT_t || $2->type == DOUBLE_t ) && ptr->value->category==INTEGER_t) ) {
								if(!($2->type==DOUBLE_t && ptr->value->category==FLOAT_t)){	
									fprintf( stdout, "########## Error at Line#%d: const type different!! ##########\n", linenum );
									semError = __TRUE;	
								}
								else{
									newNode = createConstNode( ptr->name, scope, $2, ptr->value );
									insertTab( symbolTable, newNode );
								}
							}							
							else{
								newNode = createConstNode( ptr->name, scope, $2, ptr->value );
								insertTab( symbolTable, newNode );
							}
						}
						else{
							newNode = createConstNode( ptr->name, scope, $2, ptr->value );
							insertTab( symbolTable, newNode );
						}
					}
				}
			}
			;

const_list : const_list COMMA ID ASSIGN_OP literal_const
			{				
				addConstParam( $1, createConstParam( $5, $3 ) );
				$$ = $1;
			}
		   | ID ASSIGN_OP literal_const
			{
				$$ = createConstParam( $3, $1 );	
			}
		   ;

compound_statement : {scope++;}L_BRACE var_const_stmt_list R_BRACE
					{ 
						// print contents of current scope
						if( Opt_Symbol == 1 )
							printSymTable( symbolTable, scope );
							
						deleteScope( symbolTable, scope );	// leave this scope, delete...
						scope--; 
					}
				   ;

var_const_stmt_list : var_const_stmt_list statement	
				    | var_const_stmt_list var_decl
					| var_const_stmt_list const_decl
				    |
				    ;

statement : compound_statement
		  | simple_statement
		  | conditional_statement
		  | while_statement
		  | for_statement
		  | function_invoke_statement
		  | jump_statement
		  ;		

simple_statement : variable_reference ASSIGN_OP logical_expression SEMICOLON
					{
						// check if LHS exists
                        struct SymNode *node;
						__BOOLEAN flagLHS = verifyExistence(&node, symbolTable, $1, scope, __TRUE );
						// id RHS is not dereferenced, check and deference
						__BOOLEAN flagRHS = __TRUE;
						if( $3->isDeref == __FALSE ) {
                            struct SymNode *node2;
							flagRHS = verifyExistence(&node2, symbolTable, $3, scope, __FALSE );
						}
						// if both LHS and RHS are exists, verify their type
						if( flagLHS==__TRUE && flagRHS==__TRUE )
							verifyAssignmentTypeMatch( $1, $3 );

                        //generic assign IR
                        if( node!=0 ){
                           if(node->category==VARIABLE_t){
                                 if(node->scope>0){
                                    switch(node->type->type){
                                        case INTEGER_t:
                                            fprintf(output,"\tistore %d\n",node->addr);
                                            break;
                                        case FLOAT_t:
                                            fprintf(output,"\tfstore %d\n",node->addr);
                                            break;
                                        case DOUBLE_t:
                                            fprintf(output,"\tdstore %d\n",node->addr);
                                            break;
                                        case BOOLEAN_t:
                                            fprintf(output,"\tistore %d\n",node->addr);
                                            break;
                                    }
                                 }else{
                                    switch(node->type->type){
                                        case INTEGER_t:
                                            fprintf(output,"\tputstatic %s/%s I\n",filename,node->name);
                                            break;
                                        case FLOAT_t:
                                            fprintf(output,"\tputstatic %s/%s F\n",filename,node->name);
                                            break;
                                        case DOUBLE_t:
                                            fprintf(output,"\tputstatic %s/%s D\n",filename,node->name);
                                            break;
                                        case BOOLEAN_t:
                                            fprintf(output,"\tputstatic %s/%s Z\n",filename,node->name);
                                            break;
                                    }
                                 }
                           }
                       }
					}
				 | PRINT {fprintf(output,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");} 
                   logical_expression SEMICOLON 
                    { 
                        verifyScalarExpr( $3, "print"); 
                        fprintf(output,"\tinvokevirtual java/io/PrintStream/print(");
                        switch($3->pType->type){
                            case INTEGER_t: 
                                fprintf(output,"I");
                                break;
                            case BOOLEAN_t: 
                                fprintf(output,"Z");
                                break;
                            case STRING_t: 
                                fprintf(output,"Ljava/lang/String;");
                                break;
                            case FLOAT_t: 
                                fprintf(output,"F");
                                break;
                            case DOUBLE_t:   
                                fprintf(output,"D");
                        }
                        fprintf(output,")V\n");
                    }
				 | READ variable_reference SEMICOLON 
					{ 
                        struct SymNode *node;
						if( verifyExistence(&node, symbolTable, $2, scope, __TRUE ) == __TRUE )						
							verifyScalarExpr( $2, "read" ); 

                        //generic read IR
                        if( node!=0 ){
                           if(node->category==VARIABLE_t){
                                 if(node->scope>0){
                                    switch(node->type->type){
                                        case INTEGER_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
                                            fprintf(output,"\tistore %d\n",node->addr);
                                            break;
                                        case FLOAT_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextFloat()F\n");
                                            fprintf(output,"\tfstore %d\n",node->addr);
                                            break;
                                        case DOUBLE_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextDouble()D\n");
                                            fprintf(output,"\tdstore %d\n",node->addr);
                                            break;
                                        case BOOLEAN_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextBoolean()Z\n");
                                            fprintf(output,"\tistore %d\n",node->addr);
                                            break;
                                    }
                                 }else{
                                    switch(node->type->type){
                                        case INTEGER_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
                                            fprintf(output,"\tputstatic %s/%s I\n",filename,node->name);
                                            break;
                                        case FLOAT_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
                                            fprintf(output,"\tputstatic %s/%s I\n",filename,node->name);
                                            break;
                                        case DOUBLE_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
                                            fprintf(output,"\tputstatic %s/%s I\n",filename,node->name);
                                            break;
                                        case BOOLEAN_t:
                                            fprintf(output,"\tgetstatic %s/_sc Ljava/util/Scanner;\n",filename);
                                            fprintf(output,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
                                            fprintf(output,"\tputstatic %s/%s I\n",filename,node->name);
                                            break;
                                    }
                                 }
                           }
                       }
                        
					}
				 ;

conditional_statement : IF L_PAREN conditional_if R_PAREN compound_statement { generate_if_false(); generate_if_end(); }
					  | IF L_PAREN conditional_if R_PAREN compound_statement
						ELSE  { generate_if_false();} compound_statement {generate_if_end(); }
					  ;
conditional_if : logical_expression { verifyBooleanExpr( $1, "if" ); generate_if_true();};;					  

				
while_statement : WHILE {fprintf(output,"L%d_%d_begin:\n",scope,lable[scope]);} 
                    L_PAREN logical_expression { verifyBooleanExpr( $4, "while" ); generate_if_true(); } R_PAREN { inloop++; }
					compound_statement { inloop--; generate_while_false(); }
				| { inloop++; fprintf(output,"L%d_%d_begin:\n",scope,lable[scope]); } 
                    DO compound_statement WHILE L_PAREN logical_expression R_PAREN SEMICOLON  
					{ 
						 verifyBooleanExpr( $6, "while" );
						 inloop--; 
						 generate_dowhile();
					}
				; 


				
for_statement : FOR L_PAREN initial_expression SEMICOLON 
                {generate_for_begin();} control_expression SEMICOLON 
                {generate_for_inc();}increment_expression R_PAREN  
                { inloop++; generate_for_true(); }compound_statement  { inloop--; generate_for_false();}
			  ; 

initial_expression : initial_expression COMMA statement_for		
				   | initial_expression COMMA logical_expression
				   | logical_expression	
				   | statement_for
				   |
				   ;

control_expression : control_expression COMMA statement_for
				   {
						fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
						semError = __TRUE;	
				   }
				   | control_expression COMMA logical_expression
				   {
						if( $3->pType->type != BOOLEAN_t ){
							fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
							semError = __TRUE;	
						}
				   }
				   | logical_expression 
					{ 
						if( $1->pType->type != BOOLEAN_t ){
							fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
							semError = __TRUE;	
						}
					}
				   | statement_for
				   {
						fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
						semError = __TRUE;	
				   }
				   |
				   ;

increment_expression : increment_expression COMMA statement_for
					 | increment_expression COMMA logical_expression
					 | logical_expression
					 | statement_for
					 |
					 ;

statement_for 	: variable_reference ASSIGN_OP logical_expression
					{
						// check if LHS exists
                        struct SymNode *node,*node2;
						__BOOLEAN flagLHS = verifyExistence(&node, symbolTable, $1, scope, __TRUE );
						// id RHS is not dereferenced, check and deference
						__BOOLEAN flagRHS = __TRUE;
						if( $3->isDeref == __FALSE ) {
							flagRHS = verifyExistence(&node2, symbolTable, $3, scope, __FALSE );
						}
						// if both LHS and RHS are exists, verify their type
						if( flagLHS==__TRUE && flagRHS==__TRUE )
							verifyAssignmentTypeMatch( $1, $3 );
                        //generic assign IR
                        if( node!=0 ){
                           if(node->category==VARIABLE_t){
                                 if(node->scope>0){
                                    switch(node->type->type){
                                        case INTEGER_t:
                                            fprintf(output,"\tistore %d\n",node->addr);
                                            break;
                                        case FLOAT_t:
                                            fprintf(output,"\tfstore %d\n",node->addr);
                                            break;
                                        case DOUBLE_t:
                                            fprintf(output,"\tdstore %d\n",node->addr);
                                            break;
                                        case BOOLEAN_t:
                                            fprintf(output,"\tistore %d\n",node->addr);
                                            break;
                                    }
                                 }else{
                                    switch(node->type->type){
                                        case INTEGER_t:
                                            fprintf(output,"\tputstatic %s/%s I\n",filename,node->name);
                                            break;
                                        case FLOAT_t:
                                            fprintf(output,"\tputstatic %s/%s F\n",filename,node->name);
                                            break;
                                        case DOUBLE_t:
                                            fprintf(output,"\tputstatic %s/%s D\n",filename,node->name);
                                            break;
                                        case BOOLEAN_t:
                                            fprintf(output,"\tputstatic %s/%s Z\n",filename,node->name);
                                            break;
                                    }
                                 }
                           }
                       }
					}
					;
					 
					 
function_invoke_statement : ID L_PAREN logical_expression_list R_PAREN SEMICOLON
							{
								verifyFuncInvoke( $1, $3, symbolTable, scope );
							}
						  | ID L_PAREN R_PAREN SEMICOLON
							{
								verifyFuncInvoke( $1, 0, symbolTable, scope );
							}
						  ;

jump_statement : CONTINUE SEMICOLON
				{
					if( inloop <= 0){
						fprintf( stdout, "########## Error at Line#%d: continue can't appear outside of loop ##########\n", linenum ); semError = __TRUE;
					}
				}
			   | BREAK SEMICOLON 
				{
					if( inloop <= 0){
						fprintf( stdout, "########## Error at Line#%d: break can't appear outside of loop ##########\n", linenum ); semError = __TRUE;
					}
				}
			   | RETURN logical_expression SEMICOLON
				{
                    if( is_main ){
                        fprintf(output,"\treturn\n");
                    }
                    else{
                        verifyReturnStatement( $2, funcReturn );
                        //generate return IR
                        switch(funcReturn->type){
                            case INTEGER_t:
                            case BOOLEAN_t:
                                fprintf(output,"\tireturn\n");
                                break;
                            case FLOAT_t:
                                fprintf(output,"\tfreturn\n");
                                break;
                            case DOUBLE_t:
                                fprintf(output,"\tdreturn\n");
                        }
                    }
				}
			   ;

variable_reference : ID
					{
						$$ = createExprSem( $1 );
					}
				   ;

logical_expression : logical_expression OR_OP logical_term
					{
						verifyAndOrOp( $1, OR_t, $3 );
						$$ = $1;
					}
				   | logical_term { $$ = $1; }
				   ;

logical_term : logical_term AND_OP logical_factor
				{
					verifyAndOrOp( $1, AND_t, $3 );
					$$ = $1;
				}
			 | logical_factor { $$ = $1; }
			 ;

logical_factor : NOT_OP logical_factor
				{
					verifyUnaryNOT( $2 );
					$$ = $2;
				}
			   | relation_expression { $$ = $1; }
			   ;

relation_expression : arithmetic_expression relation_operator arithmetic_expression
					{
						verifyRelOp( $1, $2, $3 );
						$$ = $1;
					}
					| arithmetic_expression { $$ = $1; }
					;

relation_operator : LT_OP { $$ = LT_t; }
				  | LE_OP { $$ = LE_t; }
				  | EQ_OP { $$ = EQ_t; }
				  | GE_OP { $$ = GE_t; }
				  | GT_OP { $$ = GT_t; }
				  | NE_OP { $$ = NE_t; }
				  ;

arithmetic_expression : arithmetic_expression add_op term
			{
				verifyArithmeticOp( $1, $2, $3 );
				$$ = $1;
                if($2==ADD_t)
                    printf("+\n");
                else
                    printf("-\n");
			}
           | relation_expression { $$ = $1; }
		   | term { $$ = $1; }
		   ;

add_op	: ADD_OP { $$ = ADD_t; }
		| SUB_OP { $$ = SUB_t; }
		;
		   
term : term mul_op factor
		{
            if($2 == DIV_t)
                printf("/\n");
            else if($2 == MUL_t)
                printf("*\n");
            else
                printf("%%\n");
			if( $2 == MOD_t ) {
				verifyModOp( $1, $3 );
			}
			else {
				verifyArithmeticOp( $1, $2, $3 );
			}
			$$ = $1;
		}
     | factor { $$ = $1; }
	 ;

mul_op 	: MUL_OP { $$ = MUL_t; }
		| DIV_OP { $$ = DIV_t; }
		| MOD_OP { $$ = MOD_t; }
		;
		
factor : variable_reference
		{
            struct SymNode *node;
			verifyExistence(&node, symbolTable, $1, scope, __FALSE );
			$$ = $1;
			$$->beginningOp = NONE_t;
            if( node!=0 ){
               if(node->category==VARIABLE_t||node->category==PARAMETER_t){
                     if(node->scope>0){
                        switch(node->type->type){
                            case INTEGER_t:
                                fprintf(output,"\tiload %d\n",node->addr);
                                break;
                            case FLOAT_t:
                                fprintf(output,"\tfload %d\n",node->addr);
                                break;
                            case DOUBLE_t:
                                fprintf(output,"\tdload %d\n",node->addr);
                                break;
                            case BOOLEAN_t:
                                fprintf(output,"\tiload %d\n",node->addr);
                                break;
                        }
                     }else{
                        fprintf(output,"getstatic %s/%s ",filename,node->name);
                        switch(node->type->type){
                            case INTEGER_t:
                                fprintf(output,"I\n");
                                break;
                            case FLOAT_t:
                                fprintf(output,"F\n");
                                break;
                            case DOUBLE_t:
                                fprintf(output,"D\n");
                                break;
                            case BOOLEAN_t:
                                fprintf(output,"I\n");
                                break;
                        }
                     }
               }
               else if(node->category==CONSTANT_t){
					switch( node->attribute->constVal->category ) {
					 case INTEGER_t:
						fprintf(output,"\tldc %d\n",node->attribute->constVal->value.integerVal);
						break;
					 case FLOAT_t:
					 	fprintf(output,"\tldc %lf\n",node->attribute->constVal->value.floatVal);
						break;
					case DOUBLE_t:
					 	fprintf(output,"\tldc %lf\n",node->attribute->constVal->value.doubleVal);
						break;
					 case BOOLEAN_t:
					 	if( node->attribute->constVal->value.booleanVal == __TRUE ) 
							fprintf(output,"\ticonst_1\n");
						else
							fprintf(output,"\ticonst_0\n");
						break;
					 case STRING_t:
					 	fprintf(output,"ldc \"%s\"",node->attribute->constVal->value.stringVal);
						break;
					}
               }
            }
		}
	   | SUB_OP variable_reference
		{
            struct SymNode *node;
			if( verifyExistence(&node, symbolTable, $2, scope, __FALSE ) == __TRUE ){
                if( node!=0 ){
                   if(node->category==VARIABLE_t||node->category==PARAMETER_t){
                         if(node->scope>0){
                            switch(node->type->type){
                                case INTEGER_t:
                                    fprintf(output,"\tiload %d\n",node->addr);
                                    break;
                                case FLOAT_t:
                                    fprintf(output,"\tfload %d\n",node->addr);
                                    break;
                                case DOUBLE_t:
                                    fprintf(output,"\tdload %d\n",node->addr);
                                    break;
                                case BOOLEAN_t:
                                    fprintf(output,"\tiload %d\n",node->addr);
                                    break;
                            }
                         }else{
                            fprintf(output,"getstatic %s/%s ",filename,node->name);
                            switch(node->type->type){
                                case INTEGER_t:
                                    fprintf(output,"I\n");
                                    break;
                                case FLOAT_t:
                                    fprintf(output,"F\n");
                                    break;
                                case DOUBLE_t:
                                    fprintf(output,"D\n");
                                    break;
                                case BOOLEAN_t:
                                    fprintf(output,"I\n");
                                    break;
                            }
                         }
                   }
                   else if(node->category==CONSTANT_t){
                        switch( node->attribute->constVal->category ) {
                         case INTEGER_t:
                            fprintf(output,"\tldc %d\n",node->attribute->constVal->value.integerVal);
                            break;
                         case FLOAT_t:
                            fprintf(output,"\tldc %lf\n",node->attribute->constVal->value.floatVal);
                            break;
                        case DOUBLE_t:
                            fprintf(output,"\tldc %lf\n",node->attribute->constVal->value.doubleVal);
                            break;
                         case BOOLEAN_t:
                            if( node->attribute->constVal->value.booleanVal == __TRUE ) 
                                fprintf(output,"\ticonst_1\n");
                            else
                                fprintf(output,"\ticonst_0\n");
                            break;
                         case STRING_t:
                            fprintf(output,"ldc \"%s\"",node->attribute->constVal->value.stringVal);
                            break;
                        }
                   }
                }
                
                verifyUnaryMinus( $2 );
            }
			$$ = $2;
			$$->beginningOp = SUB_t;
		}		
	   | L_PAREN logical_expression R_PAREN
		{
			$2->beginningOp = NONE_t;
			$$ = $2; 
		}
	   | SUB_OP L_PAREN logical_expression R_PAREN
		{
			verifyUnaryMinus( $3 );
			$$ = $3;
			$$->beginningOp = SUB_t;
		}
	   | ID L_PAREN logical_expression_list R_PAREN
		{
			$$ = verifyFuncInvoke( $1, $3, symbolTable, scope );
			$$->beginningOp = NONE_t;
		}
	   | SUB_OP ID L_PAREN logical_expression_list R_PAREN
	    {
			$$ = verifyFuncInvoke( $2, $4, symbolTable, scope );
			$$->beginningOp = SUB_t;
		}
	   | ID L_PAREN R_PAREN
		{
			$$ = verifyFuncInvoke( $1, 0, symbolTable, scope );
			$$->beginningOp = NONE_t;
		}
	   | SUB_OP ID L_PAREN R_PAREN
		{
			$$ = verifyFuncInvoke( $2, 0, symbolTable, scope );
			$$->beginningOp = SUB_OP;
		}
	   | literal_const
	    {
			  $$ = (struct expr_sem *)malloc(sizeof(struct expr_sem));
			  $$->isDeref = __TRUE;
			  $$->varRef = 0;
			  $$->pType = createPType( $1->category );
			  $$->next = 0;
			  if( $1->hasMinus == __TRUE ) {
			  	$$->beginningOp = SUB_t;
			  }
			  else {
				$$->beginningOp = NONE_t;
			  }
		}
	   ;

logical_expression_list : logical_expression_list COMMA logical_expression
						{
			  				struct expr_sem *exprPtr;
			  				for( exprPtr=$1 ; (exprPtr->next)!=0 ; exprPtr=(exprPtr->next) );
			  				exprPtr->next = $3;
			  				$$ = $1;
						}
						| logical_expression { $$ = $1; }
						;

		  


scalar_type : INT { $$ = createPType( INTEGER_t ); }
			| DOUBLE { $$ = createPType( DOUBLE_t ); }
			| STRING { $$ = createPType( STRING_t ); }
			| BOOL { $$ = createPType( BOOLEAN_t ); }
			| FLOAT { $$ = createPType( FLOAT_t ); }
			;
 
literal_const : INT_CONST
				{
					int tmp = $1;
					$$ = createConstAttr( INTEGER_t, &tmp );
                    printf("const : %d\n",$1);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc %d\n",$1);
				}
			  | SUB_OP INT_CONST
				{
					int tmp = -$2;
					$$ = createConstAttr( INTEGER_t, &tmp );
                    printf("const : %d\n",-$2);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc %d\n",-$2);
				}
			  | FLOAT_CONST
				{
					float tmp = $1;
					$$ = createConstAttr( FLOAT_t, &tmp );
                    printf("const : %f\n",$1);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc %f\n",$1);
				}
			  | SUB_OP FLOAT_CONST
			    {
					float tmp = -$2;
					$$ = createConstAttr( FLOAT_t, &tmp );
                    printf("const : %f\n",-$2);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc %f\n",-$2);
				}
			  | SCIENTIFIC
				{
					double tmp = $1;
					$$ = createConstAttr( DOUBLE_t, &tmp );
                    printf("const : %f\n",$1);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc %f\n",$1);
				}
			  | SUB_OP SCIENTIFIC
				{
					double tmp = -$2;
					$$ = createConstAttr( DOUBLE_t, &tmp );
                    printf("const : %f\n",-$2);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc %f\n",-$2);
				}
			  | STR_CONST
				{
					$$ = createConstAttr( STRING_t, $1 );
                    printf("const : %s\n",$1);
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\tldc \"%s\"\n",$1);
				}
			  | TRUE
				{
					SEMTYPE tmp = __TRUE;
					$$ = createConstAttr( BOOLEAN_t, &tmp );
                    printf("const : true\n");
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\ticonst_1\n");
				}
			  | FALSE
				{
					SEMTYPE tmp = __FALSE;
					$$ = createConstAttr( BOOLEAN_t, &tmp );
                    printf("const : false\n");
                    if(scope>0)     //fprintf(output,"\t");
                        fprintf(output,"\ticonst_0\n");
				}
			  ;
%%

int yyerror( char *msg )
{
    fprintf( stderr, "\n|--------------------------------------------------------------------------\n" );
	fprintf( stderr, "| Error found in Line #%d: %s\n", linenum, buf );
	fprintf( stderr, "|\n" );
	fprintf( stderr, "| Unmatched token: %s\n", yytext );
	fprintf( stderr, "|--------------------------------------------------------------------------\n" );
	exit(-1);
}


