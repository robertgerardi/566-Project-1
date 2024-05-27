North Carolina State University - ECE 566 - Compiler Optimization and Scheduling

High Level Overview 

o A Lexer and Parser were created to take in various expressions, syntax, and arguments, using the LLVM Library.

o The lexer would identify specific expressions and syntax, while the parser would take those expressions and arguments identified by the lexer, and perform specfic tasks based on the ordering.

o Ultimately, the entire program was aimed to perform specific matrix tasks, like multiplication, transpose, and others. I was able to get most of the functions working, however there are still some parts missing, such as 4x4 multiplication

File Descriptions

p1.lex - lexer that identifies arguments, expressions, and syntax.

p1.y - parser that identifies groups of arguments, expressions, or syntax, and performs specific tasks.
