/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
String handling header
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/


#ifndef STRING_H
#define STRING_H

#include <stdio.h>    // core input and output functions
#include <stdlib.h>   // standard general utilities library
#include <string.h>   // string handling functions
#include <limits.h>   // macro constants of the integer types
#include <errno.h>    // error numbers

#include "const.h"
#include "alloc.h"

#ifdef __cplusplus
extern "C" {
#endif

void copy_string(char *dst, size_t size, const char *src);
void concat_string_2(char *dst, size_t size, const char *src1, const char *src2, const char *delim);
void concat_string_3(char *dst, size_t size, const char *src1, const char *src2, const char *src3, const char *delim);
void replace_string(char *src, const char *search, const char *replace, size_t src_len);
int char_to_int(const char *src, int *val);
int char_to_float(const char *src, float *val);

#ifdef __cplusplus
}
#endif

#endif

