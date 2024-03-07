/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Allocation header
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/


#ifndef ALLOC_H
#define ALLOC_H

#include <stdio.h>   // core input and output functions
#include <stdlib.h>  // standard general utilities library
#include <string.h>  // string handling functions


#ifdef __cplusplus
extern "C" {
#endif

void alloc(void **ptr, size_t n, size_t size);
void alloc_2D(void ***ptr, size_t n1, size_t n2, size_t size);
void alloc_3D(void ****ptr, size_t n1, size_t n2, size_t n3, size_t size);
void alloc_2DC(void ***ptr, size_t n1, size_t n2, size_t size);
void re_alloc(void **ptr, size_t n_now, size_t n, size_t size);
void re_alloc_2D(void ***ptr, size_t n1_now, size_t n2_now, size_t n1, size_t n2, size_t size);
void re_alloc_3D(void ****ptr, size_t n1_now, size_t n2_now, size_t n3_now, size_t n1, size_t n2, size_t n3, size_t size);
void re_alloc_2DC(void ***ptr, size_t n1_now, size_t n2_now, size_t n1, size_t n2, size_t size);
void free_2D(void **ptr, size_t n);
void free_3D(void ***ptr, size_t n1, size_t n2);
void free_2DC(void **ptr);

#ifdef __cplusplus
}
#endif

#endif

