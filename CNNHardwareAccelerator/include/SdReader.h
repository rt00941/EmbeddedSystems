#include "exception"
#include "string"
#include "sstream"
#include "xparameters.h"	/* SDK generated parameters */
#include "xsdps.h"		/* SD device driver */
#include <stdio.h>
#include "../include/ff.h"

void ReadFloatsFromSDFile(std::stringstream &stream, const std::string file_name);
void ReadBytesFromSDFile(std::stringstream &stream, const std::string file_name);
