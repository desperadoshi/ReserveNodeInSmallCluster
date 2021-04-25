#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include "mpi.h"
#include <thread>
#include <chrono>
#include <string>
#include <cmath>
#include "sys/stat.h"

/*
 * Cehck [Fastest way to check if a file exist using standard C++/C++11/C?](https://stackoverflow.com/questions/12774207/fastest-way-to-check-if-a-file-exist-using-standard-c-c11-c) for more general way of checking file.
 * The following implementation uses posix stat().
 */
inline bool exists_test (const std::string& name) {
  struct stat buffer;   
  return (stat(name.c_str(), &buffer) == 0); 
}

int main(int argc, char* argv[]) {

  int ncpu, proc;

  MPI_Init(&argc, &argv);

  MPI_Comm_size(MPI_COMM_WORLD, &ncpu);
  MPI_Comm_rank(MPI_COMM_WORLD, &proc);

  if (proc==0) {
    printf("Program starts\n");
  }

  // Create a file to indicate that the program is running
  std::string indicator_fname = "solver_is_running";
  std::ofstream indicator_f;
  if (proc==0) {
    indicator_f.open(indicator_fname);
  }

  // int sleep_duration = 1; // seconds
  std::string request_fname = "stop_occupy";
  bool file_exist = false;

  bool not_request_stop = true;
  int ierr;
  int N1 = 1024*1024*256, N2=5;
  double f=0.0;
  double* arr = new double[N1];
  while (not_request_stop) {
    // std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();
    f = 0.0;
    for (int j=0; j<N2; j++) {
      for (int i=0; i<N1; i++) {
        f += sqrt(1E-6);
        arr[i] += sin(f);
      }
      for (int i=0; i<N1; i++) {
        arr[i] = 0.0;
      }
    }
    // std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();
    // if (proc==0) {
    //   std::cout << "Time difference = " << std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count() << "[µs]" << std::endl;
    // }
    // std::this_thread::sleep_for(std::chrono::minutes(sleep_duration));
    // std::this_thread::sleep_for(std::chrono::seconds(sleep_duration));
    // Check if the request of stop is found
    file_exist = false;
    if (proc==0) {
      file_exist = exists_test(request_fname);
    }
    // communicate
    ierr = MPI_Allreduce(MPI_IN_PLACE, &file_exist, 1, MPI_C_BOOL, MPI_LOR, MPI_COMM_WORLD);
    if( file_exist ) {
      not_request_stop = false;
      // delete the request file and exit
      if (proc==0) {
        ierr = remove(request_fname.c_str());
      }
      // break;
    }
  }
  if (proc==0) {
    if (ierr!=0) {
      printf("remove %s fails!\n", request_fname.c_str());
    }
    // printf("End\n");
  }

  delete[] arr;
  if (proc==0) {
    indicator_f.close();
    ierr = remove(indicator_fname.c_str());
  }
  if (proc==0) {
    printf("Program stops\n");
  }
  MPI_Finalize();

  return 0;
}
