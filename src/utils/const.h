/**+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Named constant definitions
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**/


#ifndef CONSTANT_H
#define CONSTANT_H

#ifdef __cplusplus
extern "C" {
#endif

// abbreviated datatypes
typedef unsigned short int ushort;
typedef unsigned char small;

// pi
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// radians to degree conversion
#define _R2D_CONV_  57.29577951308232286465
#define _D2R_CONV_   0.01745329251994329547

// string length
#define STRLEN 1024

// function return codes
#define SUCCESS 0
#define FAILURE 1
#define CANCEL 9

#ifdef __cplusplus
}
#endif

#endif

