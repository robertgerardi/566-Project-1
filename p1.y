%{
#include <cstdio>
#include <list>
#include <vector>
#include <map>
#include <iostream>
#include <fstream>
#include <string>
#include <memory>
#include <stdexcept>


#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Verifier.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/FileSystem.h"

using namespace llvm;
using namespace std;


// Need for parser and scanner
extern FILE *yyin;
int yylex();
void yyerror(const char*);
int yyparse();
 
// Needed for LLVM
string funName;
Module *M;
LLVMContext TheContext;
 IRBuilder<> Builder(TheContext);

 map<string,Value*> IDMap;
 map<string,vector<vector<Value*>*>*> Mmap;

 struct Matrix_or_float{ // stucture for expr

   bool isMatrix;
   bool isFloat;
   int rows;
   int columns;
   Value* value;
   char* mname;
   vector<vector<Value*>*> *mnew;
  

 };
 struct dim{ // stucture for dimensions

   int rows;
   int columns;

 };

%}


%union { // union list

  vector<string> *parameterlist; // vector for parameters
  vector<Value*> *exprlist; // vector for matrix expr list
  vector<vector<Value*>*> *matrixrows; // matrix rows vector
  
  struct Matrix_or_float mof;
  struct dim dim;
  int ival;
  float fval;
  char* ID;
  

  
}

%define parse.trace

%token ERROR

%token RETURN
%token DET TRANSPOSE INVERT
%token REDUCE
%token MATRIX
%token X

%token <fval>FLOAT
%token <ival> INT
%token <ID> ID

%token SEMI COMMA

%token PLUS MINUS MUL DIV
%token ASSIGN

%token LBRACKET RBRACKET
%token LPAREN RPAREN 
%token LBRACE RBRACE 

%type <parameterlist> params_list
%type <mof> expr

%type <matrixrows> matrix_rows
%type <exprlist> matrix_row expr_list
%type <dim> dim

%left PLUS MINUS
%left MUL DIV 

%start program

%%

program: ID {
 
  funName = $1; // function name is now id
} LPAREN params_list_opt RPAREN LBRACE statements_opt return RBRACE
{
  // parsing is done, input is accepted
  YYACCEPT;
}
;


params_list_opt:  params_list 
{
  //parameter list size is now put into vector type
  std::vector<Type*> param_types($1->size(),Builder.getFloatTy());  
  ArrayRef<Type*> Params (param_types);
  
  // Create int function type with no arguments
  FunctionType *FunType = 
    FunctionType::get(Builder.getFloatTy(),Params,false);

  // Create a main function
  Function *Function = Function::Create(FunType,GlobalValue::ExternalLinkage,funName,M);

  int arg_no=0;

  
  for(auto &a: Function->args()) {

   

    IDMap[$1->at(arg_no)] = &a; // argument assigned to value in map

  

   
    arg_no++; //increment the agruments in the vector so it can parse

    
   
  }
  
  //Add a basic block to main to hold instructions, and set Builder
  //to insert there
  Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
}
| %empty
{ 
  // Create int function type with no arguments
  FunctionType *FunType = 
    FunctionType::get(Builder.getFloatTy(),false);

  // Create a main function
  Function *Function = Function::Create(FunType,  
         GlobalValue::ExternalLinkage,funName,M);

  //Add a basic block to main to hold instructions, and set Builder
  //to insert there
  Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
}
;

params_list: ID
{
  $$ = new vector<string>;
  string s = $1;
    $$->push_back(s);//ID is remembered and pushed back 
}
| params_list COMMA ID
{
  string s = $3;
  $1->push_back(s);//ID is remembered and pushed back
}
;

return: RETURN expr SEMI
{
  if($2.isMatrix && $2.value == NULL){
    YYABORT;
  }
   Builder.CreateRet($2.value);
  return 0;
}
;

// These may be fine without changes
statements_opt: %empty
            | statements
;

// These may be fine without changes
statements:   statement
            | statements statement
;

//assign statements are created, one for expr and one for a matrix assignment
statement:
  ID ASSIGN expr SEMI
  {

    if($3.isFloat){
      IDMap[$1] = $3.value;
     
    }
   
    else if($3.isMatrix &&(Mmap.find($1)== Mmap.end())){

	Mmap[$1] = $3.mnew;

    }
    
  }
| ID ASSIGN MATRIX dim LBRACE matrix_rows RBRACE SEMI

{

  Mmap[$1] = $6;
}
;

//dimensions are acccounted for 
dim: LBRACKET INT X INT RBRACKET
{

  $$.rows = $2;
  $$.columns = $4;

}
;

//matrix rows are implemented using a 2D vector
matrix_rows: matrix_row
{
  $$ = new vector<vector<Value*>*>;
  $$->push_back($1);
}
| matrix_rows COMMA matrix_row
{
  $1->push_back($3);
}
;

//single matrix row is implemented 
matrix_row: LBRACKET expr_list RBRACKET
{
  $$ = $2;

}
;

//expr list is pushed to vector for single matrix row
expr_list: expr
{
  $$ = new vector<Value*>;
  $$->push_back($1.value);
}
| expr_list COMMA expr
{ 
 $1->push_back($3.value);
}
;

//ID is remembered
expr: ID
{
  //if id is not found, abort
  if (IDMap.find($1)==IDMap.end() && Mmap.find($1)== Mmap.end()) { //check to see if I am accessing an undefined variable
	     printf("Undefined!\n");
	     YYABORT;
	   }
  
  else if(IDMap.find($1)!=IDMap.end()){ // if id is is not found id map, create a spot
        $$.value = IDMap[$1];
	$$.isFloat = true;
	$$.isMatrix = false;

	cout << "TEST ID" << endl;
	
	 
    }
  else{ // if its not a regular ID, it is a mtrix and assign to matrix map
      cout << "TEST MATRIX" << endl;
      $$.isMatrix = true;
      $$.isFloat = false;
      $$.mname = $1;
      $$.rows = Mmap.at($1)->size();
      cout << "ROWS: "<< $$.rows << endl;
      $$.columns = Mmap.at($1)->at(0)->size();
      cout << "COLUMNS: "<< $$.columns << endl;
     

    }

}
| FLOAT
{ // create simple float
  $$.isFloat = true;
  $$.isMatrix = false;
  $$.value = ConstantFP::get(Builder.getFloatTy(),APFloat($1));
}
| INT
{ // convert int to float
   $$.isFloat = true;
   $$.isMatrix = false;
  $$.value = Builder.CreateUIToFP(Builder.getInt32($1),Builder.getFloatTy());
   cout<< "TEST NEW4" << endl;
}
| expr PLUS expr
{
  //////////////
  if($1.isMatrix && $3.isMatrix){ //matrix addition
   
    $$.isMatrix = true;
    $$.isFloat = false;
    $$.rows = $1.rows;
    $$.columns = $1.columns;
    $$.mnew = new vector<vector<Value*>*>;
   
    for(int i = 0; i<$1.rows; i++){
      vector<Value*>* temp = new vector<Value*>; // new matrix is allocated
     
      for(int j = 0; j<$1.columns; j++){

 Value* addv = NULL;
 Value* test1 = NULL;
 Value* test2 = NULL;

 test1 = Mmap.at($1.mname)->at(i)->at(j);

 test2 = Mmap.at($3.mname)->at(i)->at(j);
 
 addv = Builder.CreateFAdd(test1,test2 , "add");//adds both points in matrices 


 temp->push_back(addv);//pushes onto matrix row
	


      }
      $$.mnew->push_back(temp);//pushes row onto matrix 
   }

  }
  else{
    //if they are not a matrix, then its a float and you can add them normally
    $$.isFloat = true;
    $$.isMatrix = false;
  $$.value = Builder.CreateFAdd($1.value, $3.value, "add");
  }
  /////////////////
}
| expr MINUS expr
{
  if($1.isMatrix && $3.isMatrix){//matrix subtraction
   
    $$.isMatrix = true;
    $$.isFloat = false;
    $$.rows = $1.rows;
    $$.columns = $1.columns;
    $$.mnew = new vector<vector<Value*>*>;
   
    for(int i = 0; i<$1.rows; i++){
      vector<Value*>* temp = new vector<Value*>;//allocate not matrix
     
      for(int j = 0; j<$1.columns; j++){

 Value* subv = NULL;
 Value* test1 = NULL;
 Value* test2 = NULL;

 test1 = Mmap.at($1.mname)->at(i)->at(j);

 test2 = Mmap.at($3.mname)->at(i)->at(j);
 
 subv = Builder.CreateFSub(test1,test2 , "sub"); //subract two matrix points


 temp->push_back(subv); //push element onto matrix row
	


      }
      $$.mnew->push_back(temp);//push row onto matrix
   }

  }
  else{
     
    $$.isFloat = true;
    $$.isMatrix = false;
    $$.value = Builder.CreateFSub($1.value, $3.value, "sub"); //regular subtraction if both floats
  }
}
| expr MUL expr
{
  
 cout<< "TEST NEW3" << endl;
 if($1.isMatrix && $3.isMatrix){// matrix multiplication
     
     if($1.columns != $3.rows){
       YYABORT;
     }
     $$.isFloat = false;
     $$.isMatrix = true;


     $$.mnew = new vector<vector<Value*>*>; //allocate new matrix
   
    for(int i = 0; i<$1.rows; i++){
      vector<Value*>* temp = new vector<Value*>;
      
     
     
      for(int j = 0; j<$3.columns; j++){
	
	Value* total = Builder.CreateUIToFP(Builder.getInt32(0),Builder.getFloatTy()); // create total for multiplication and initialize it to zero

	for(int k = 0; k<$1.columns; k++){
 Value* addv = NULL;
 Value* test1 = NULL;
 Value* test2 = NULL;

 if($1.mnew != NULL){
test1 = $1.mnew->at(i)->at(k);
 cout<< "TEST NEW1" << endl;
 }else{
  test1 = Mmap.at($1.mname)->at(i)->at(k);
   cout<< "TEST NEW2" << endl;
 }
	    test1->print(errs(),true);
	    cout << endl;
	   test2 = Mmap.at($3.mname)->at(k)->at(j);
	   test2->print(errs(),true);
	    cout << endl;
	    addv = Builder.CreateFMul(test1,test2 , "mul"); //perform multiplication
	    addv->print(errs(),true);
	    cout << endl;
	  
	    total = Builder.CreateFAdd(total,addv,"addtotal"); // add result to total
	  
	}


	temp->push_back(total); //push back total
	


      }
      $$.mnew->push_back(temp); // push back row 
   }


     

 }else if($1.isMatrix && $3.isFloat ){ //multiply float through if first element is matrix
     $$.isFloat = false;
     $$.isMatrix = true;


     $$.mnew = new vector<vector<Value*>*>;
   
    for(int i = 0; i<$1.rows; i++){
      vector<Value*>* temp = new vector<Value*>;
      
     
     
      for(int j = 0; j<$3.columns; j++){
	
	for(int k = 0; k<$1.columns; k++){

         Value* addv = NULL;
 Value* test1 = NULL;
 Value* test2 = NULL;

 if($1.mnew != NULL && $1.isMatrix){ //check if its in map or in pointer
test1 = $1.mnew->at(i)->at(j);
   test2 =$3.value;

 }else {
  test1 = Mmap.at($1.mname)->at(i)->at(j);
    test2 =$3.value;

 }
	  
	  
	 
	 
 addv = Builder.CreateFMul(test1,test2 , "mul"); //multiply float through
	  
 temp->push_back(addv); //push value to row
	}
	  
      }
      $$.mnew->push_back(temp);//push value row to matrix
   }



 }else if($1.isFloat && $3.isMatrix ){ // multiply float through if second expr is matrix
     $$.isFloat = false;
     $$.isMatrix = true;


     $$.mnew = new vector<vector<Value*>*>;//create new matrix
   
    for(int i = 0; i<$1.rows; i++){
      vector<Value*>* temp = new vector<Value*>;
      
     
     
      for(int j = 0; j<$3.columns; j++){
	
for(int k = 0; k<$1.columns; k++){

  Value* addv = NULL;
 Value* test1 = NULL;
 Value* test2 = NULL;

 if($3.mnew != NULL && $3.isMatrix){
test1 = $3.mnew->at(i)->at(j);
   test2 =$1.value;

 }else {
  test1 = Mmap.at($3.mname)->at(i)->at(j);
    test2 =$1.value;

 }
	  
	  
	 
 
 addv = Builder.CreateFMul(test1,test2 , "mul"); //multiply float through 
 
	  
 temp->push_back(addv);// push back values to row


 }
	


      }
      $$.mnew->push_back(temp); //push back row to matrix
   }



   }
 else{

  $$.isFloat = true;
  $$.isMatrix = false;
  $$.value = Builder.CreateFMul($1.value,$3.value,"mul"); // if both values are float then you can just multiply together
   }
}
| expr DIV expr
{
  //DIVISION
  if($1.isMatrix && $3.isFloat){ // if first value is matrix, divide by float
    $$.isMatrix = true;
    $$.isFloat = false;
    $$.rows = $1.rows;
    $$.columns = $1.columns;
    $$.mnew = new vector<vector<Value*>*>;
   
    for(int i = 0; i<$1.rows; i++){
      vector<Value*>* temp = new vector<Value*>; //create new matrix
     
      for(int j = 0; j<$1.columns; j++){

 Value* divv = NULL;
 Value* test1 = NULL;
 Value* test2 = NULL;

 if($1.mnew != NULL){
test1 = $1.mnew->at(i)->at(j);
 }else{
  test1 = Mmap.at($1.mname)->at(i)->at(j);
 }



 test2 =$3.value;
 
 divv = Builder.CreateFDiv(test1,test2 , "div");//divide values


 temp->push_back(divv);//push divide onto matrix row
	


      }
      $$.mnew->push_back(temp);//push row onto matrix
   }
    

  }else{
    $$.isFloat = true;
    $$.isMatrix = false;
    $$.value = Builder.CreateFDiv($1.value,$3.value,"div"); //float normal division 
      }

  

}
| MINUS expr
{
  if($2.isMatrix){ //if value is matrix, negate all values inside

    $$.isMatrix = true;
    $$.isFloat = false;
    $$.rows = $2.rows;
    $$.columns = $2.columns;
    $$.mnew = new vector<vector<Value*>*>; //create new matrix
   
    for(int i = 0; i<$2.rows; i++){
      vector<Value*>* temp = new vector<Value*>;
     
      for(int j = 0; j<$2.columns; j++){


 Value* test1 = NULL;
 Value* subv = NULL;

 if($2.mnew != NULL){
test1 = $2.mnew->at(i)->at(j);

 }else{
  test1 = Mmap.at($2.mname)->at(i)->at(j);
   
 }


 
 
 subv = Builder.CreateNeg(test1, "neg"); // negate values


 temp->push_back(subv); //push value onto row
	


      }
      $$.mnew->push_back(temp); //push row onto matrix
   }




  }else{
    $$.isFloat = true;
    $$.isMatrix = false; 
    $$.value = Builder.CreateNeg($2.value, "neg"); //if float, negate it easily
  
}
}
| DET LPAREN expr RPAREN
{
  $$.isFloat = true;
  $$.isMatrix = false;
  

  if($3.isMatrix && $3.rows == 2 && $3.columns == 2){ // 2x2 det

    Value* val1 = NULL;
    Value* val2 = NULL;

    val1 = Builder.CreateFMul(Mmap.at($3.mname)->at(0)->at(0),Mmap.at($3.mname)->at(1)->at(1),"mul");
    val2 = Builder.CreateFMul(Mmap.at($3.mname)->at(0)->at(1),Mmap.at($3.mname)->at(1)->at(0),"mul"); // multiply values needed
    $$.value = Builder.CreateFSub(val1,val2,"sub"); //subtrat and put into holding variable
  } else  if($3.isMatrix && $3.rows == 3 && $3.columns == 3){ // 3x3 det

    Value* val1 = NULL;
    Value* val2 = NULL;
    Value* val3 = NULL; 
    Value* val4 = NULL;
   
    
    val1 = Builder.CreateFMul(Mmap.at($3.mname)->at(1)->at(1),Mmap.at($3.mname)->at(2)->at(2),"mul"); // multiply values needed
    val2 = Builder.CreateFMul(Mmap.at($3.mname)->at(1)->at(2),Mmap.at($3.mname)->at(2)->at(1),"mul");
    val3 = Builder.CreateFSub(val1,val2,"sub");
    val4 = Builder.CreateFMul(Mmap.at($3.mname)->at(0)->at(0),val3,"mul");
    cout << val4 << endl;
    Value* val5 = NULL;
    Value* val6 = NULL;
    Value* val7 = NULL; 
    Value* val8 = NULL;
    
    val5 = Builder.CreateFMul(Mmap.at($3.mname)->at(1)->at(0),Mmap.at($3.mname)->at(2)->at(2),"mul");
    val6 = Builder.CreateFMul(Mmap.at($3.mname)->at(1)->at(2),Mmap.at($3.mname)->at(2)->at(0),"mul");
    val7 = Builder.CreateFSub(val5,val6,"sub");
    val8 = Builder.CreateFMul(Mmap.at($3.mname)->at(0)->at(1),val7,"mul");
 cout << val8 << endl;
    Value* val9 = NULL;
    Value* val10 = NULL;
    Value* val11 = NULL; 
    Value* val12 = NULL;
    
    val9 = Builder.CreateFMul(Mmap.at($3.mname)->at(1)->at(0),Mmap.at($3.mname)->at(2)->at(1),"mul");
    val10 = Builder.CreateFMul(Mmap.at($3.mname)->at(1)->at(1),Mmap.at($3.mname)->at(2)->at(0),"mul");
    val11 = Builder.CreateFSub(val9,val10,"sub");
    val12 = Builder.CreateFMul(Mmap.at($3.mname)->at(0)->at(2),val11,"mul");
 cout << val12 << endl;
    Value* val13;
    Value* val14;
    val13 = Builder.CreateFSub(val4,val8,"sub");
    val14 = Builder.CreateFAdd(val13,val12, "add");
    $$.value = val14;  //store values into holding variable

     val14->print(errs(),true);
	    cout << endl;

    
  }
  cout << "DET TEST" << endl;

}
| INVERT LPAREN expr RPAREN
{
  $$.isMatrix = true;
  $$.isFloat = false;
  cout << "INVERT TEST" << endl;
  if($3.rows == 2 && $3.columns == 2){

    $$.isMatrix = true;
    $$.isFloat = false;
    $$.rows = $3.rows;
    $$.columns = $3.columns;
    $$.mnew = new vector<vector<Value*>*>;

    Value * test1 = NULL;
    Value * test2 = NULL;
    Value * test3 = NULL;
    Value * test4 = NULL;
    Value * det = NULL;

    if($3.mnew != NULL){
     
      test1 =Builder.CreateFMul($3.mnew->at(0)->at(0),$3.mnew->at(1)->at(1),"mul");
      test2 =Builder.CreateFMul($3.mnew->at(0)->at(1),$3.mnew->at(1)->at(0),"mul");
      test3 = Builder.CreateFSub(test1,test2,"sub");
      test4 = Builder.CreateUIToFP(Builder.getInt32(1),Builder.getFloatTy());
      det = Builder.CreateFDiv(test4,test3,"div");

      
      
      vector<vector<Value*>*>* tempmatrix = new vector<vector<Value*>*>;
      vector<Value*> *tempmatrixrow = new vector<Value*>;
      vector<Value*> *tempmatrixrow2 = new vector<Value*>;

      Value* test6 = NULL;
      tempmatrixrow->push_back($3.mnew->at(1)->at(1));
      test6 = Builder.CreateNeg($3.mnew->at(0)->at(1));
      tempmatrixrow->push_back(test6);
      tempmatrix->push_back(tempmatrixrow);


      test6 = Builder.CreateNeg($3.mnew->at(1)->at(0));
      tempmatrixrow2->push_back(test6);
      tempmatrixrow->push_back($3.mnew->at(0)->at(0));
      
      tempmatrix->push_back(tempmatrixrow2);
	
       for(int i = 0; i<$3.rows; i++){
      vector<Value*>* temp = new vector<Value*>;
      
     
     
      for(int j = 0; j<$3.columns; j++){
	


         Value* addv = NULL;
 Value* test7 = NULL;



test7 = tempmatrix->at(i)->at(j);
   

	  
	  
	 
 
 addv = Builder.CreateFMul(test7,det , "mul"); //multiply float through 
 
	  
 temp->push_back(addv);// push back values to row


	
	


      }
      $$.mnew->push_back(temp); //push back row to matrix
   }


 
 }
  }else{
    if($3.mnew != NULL){
      $$.mnew = $3.mnew;}
    else{
      $$.mnew = Mmap[$3.mname];
    }
 }


  

 } 

| TRANSPOSE LPAREN expr RPAREN
{
  $$.isMatrix =true;
  $$.isFloat = false;
  $$.rows = $3.columns;
  $$.columns = $3.rows;
  $$.mnew = new vector<vector<Value*>*>; //create new matrix
   
    for(int i = 0; i<$3.columns; i++){
      vector<Value*>* temp = new vector<Value*>;
      
     
     
      for(int j = 0; j<$3.rows; j++){ 
	
	Value* test1 = NULL;
	test1 = Mmap.at($3.mname)->at(j)->at(i); // flips rows and columns and puts it into new matrix

	temp->push_back(test1);
	
 test1->print(errs(),true);
	    cout << endl;

      }
      $$.mnew->push_back(temp);
      cout << "TRANS TEST" << endl;
   }

  
}
| ID LBRACKET INT COMMA INT RBRACKET
{

  $$.isMatrix = false;
  $$.isFloat = true;

  $$.value = Mmap.at($1)->at($3)->at($5); //returns value at specified index
 

}
| REDUCE LPAREN expr RPAREN
{
  $$.isMatrix = false;
  $$.isFloat = true;
  Value* total = Builder.CreateUIToFP(Builder.getInt32(0),Builder.getFloatTy()); //create total variable
    for(int i = 0; i < $3.rows; i++){

    for(int j = 0; j < $3.columns; j++){


      total = Builder.CreateFAdd(total, Mmap.at($3.mname)->at(i)->at(j),"reduceadd"); //adds every value in matrix to total

     

    }




  }
    
    $$.value = total; //assigned total to holding variable 

}
| LPAREN expr RPAREN

{
  //basix expr in paren, just assigned values 
  $$.isMatrix = $2.isMatrix;
  $$.isFloat = $2.isFloat;
  $$.rows = $2.rows;
  $$.columns = $2.columns;
  $$.value = $2.value;
  $$.mname = $2.mname;
  $$.mnew = $2.mnew;
}
;


%%

unique_ptr<Module> parseP1File(const string &InputFilename)
{
  string modName = InputFilename;
  if (modName.find_last_of('/') != string::npos)
    modName = modName.substr(modName.find_last_of('/')+1);
  if (modName.find_last_of('.') != string::npos)
    modName.resize(modName.find_last_of('.'));

  // unique_ptr will clean up after us, call destructor, etc.
  unique_ptr<Module> Mptr(new Module(modName.c_str(), TheContext));

  // set global module
  M = Mptr.get();
  
  /* this is the name of the file to generate, you can also use
     this string to figure out the name of the generated function */

  if (InputFilename == "--")
    yyin = stdin;
  else	  
    yyin = fopen(InputFilename.c_str(),"r");

  //yydebug = 1;
  if (yyparse() != 0) {
    // Dump LLVM IR to the screen for debugging
    M->print(errs(),nullptr,false,true);
    // errors, so discard module
    Mptr.reset();
  } else {
    // Dump LLVM IR to the screen for debugging
    M->print(errs(),nullptr,false,true);
  }
  
  return Mptr;
}

void yyerror(const char* msg)
{
  printf("%s\n",msg);
}
