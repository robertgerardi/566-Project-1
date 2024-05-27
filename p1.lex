%{
#include <stdio.h>
#include <math.h>
#include <cstdio>
#include <list>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/IRBuilder.h"
 #include "llvm/IR/Verifier.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/FileSystem.h"

using namespace std;
using namespace llvm;

  struct Matrix_or_float{

   bool isMatrix;
   bool isFloat;
   int rows;
   int columns;
   Value* value;
    char* mname;
   vector<vector<Value*>*> *mnew;

 };

   struct dim{

   int rows;
   int columns;

   };

#include "p1.y.hpp"
 
%}

  //%option debug

%%

[ \t\n]         //ignore

return       { return RETURN; }
det          { return DET; }
transpose    { return TRANSPOSE; }
invert       { return INVERT; }
matrix       { return MATRIX; }
reduce       { return REDUCE; }
x            { return X; }

[a-zA-Z_][a-zA-Z_0-9]* {  yylval.ID = strdup(yytext); return ID; }

[0-9]+        {yylval.ival = atoi(yytext); return INT; }


[0-9]+("."[0-9]*) {yylval.fval = atof(yytext); return FLOAT; }

"["           { return LBRACKET; }
"]"           { return RBRACKET; }
"{"           { return LBRACE; }
"}"           { return RBRACE; }
"("           { return LPAREN; }
")"           { return RPAREN; }

"="           { return ASSIGN; }
"*"           { return MUL; }
"/"           { return DIV; }
"+"           { return PLUS; }
"-"           { return MINUS; }

","           { return COMMA; }

";"           { return SEMI; }


"//".*\n      { }

.             { return ERROR; }
%%

int yywrap()
{
  return 1;
}
