# CXX=mpicxx
CXX=mpiicpc
CFLAGS=-O0
PROG=solver

${PROG}: main.cpp
	${CXX} ${CFLAGS} -o ${PROG} main.cpp
clean:
	rm ${PROG}
run:
	mpirun -n 2 ${PROG}
