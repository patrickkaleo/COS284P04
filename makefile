task1.o : task1.asm
	yasm -f elf64 -g dwarf2 -l task1.lst task1.asm

task2.o:task2.asm 
	yasm -f elf64 -g dwarf2 -l task2.lst task2.asm

main.o : main.cpp	
	gcc -Wall -g -Werror -c main.c

main: main.o task1.o task2.o
	gcc -Wall -Werror -g -o main main.o task1.o task2.o

run : main
	./main

clean : 
	rm -rf *.o *.lst main task1 task2 
	clear