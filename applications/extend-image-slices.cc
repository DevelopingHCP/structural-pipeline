// =============================================================================
// Project: Image Registration Toolkit (IRTK)
// Package: PolyData
// =============================================================================


#include "mirtk/Common.h"
#include "mirtk/Options.h"

#include "mirtk/IOConfig.h"
#include "mirtk/GenericImage.h"

#include "mirtk/ImageAttributes.h"

using namespace std;
using namespace mirtk;
// =============================================================================
// Help
// =============================================================================

// -----------------------------------------------------------------------------
void PrintHelp(const char *name)
{
  cout << "usage:  " << name << " <input> <output> <options>" << endl;
  cout << endl;
  cout << "Extend image by adding slices at the specified axes." << endl;
  cout << endl;
  cout << "Options:" << endl;
  cout << "  -xyz <number>               extend the x,y,z axis by <number> at the beginning and end" << endl;
  cout << "  -xyzt <number>              extend all axis by <number> at the beginning and end" << endl;
  cout << "  -x/-y/-z/-t <number>        extend the specified axes by <number> at the beginning and end" << endl;
  cout << "  -xf/-yf/-zf/-tf <number>    extend the specified axes by <number> at the beginning" << endl;
  cout << "  -xt/-yt/-zt/-tt <number>    extend the specified axes by <number> at the end" << endl;
  cout << "  -value <double>             default value used to the added slices" << endl;
  PrintStandardOptions(cout);
  cout << endl;
}

// =============================================================================
// Main
// =============================================================================

int main(int argc, char **argv)
{
  // Positional arguments
  REQUIRES_POSARGS(2);
  InitializeIOLibrary();
  
  const char *input_image_name   = POSARG(1);
  const char *output_image_name  = POSARG(2);
  
  double value = 0;
  int xf=0, yf=0, zf=0, tf=0, xt=0, yt=0, zt=0, tt=0;
  for (ALL_OPTIONS) {
    if (OPTION("-value"))     value = atof(ARGUMENT);
    else if (OPTION("-xf"))   xf = atoi(ARGUMENT);
    else if (OPTION("-yf"))   yf = atoi(ARGUMENT);
    else if (OPTION("-zf"))   zf = atoi(ARGUMENT);
    else if (OPTION("-tf"))   tf = atoi(ARGUMENT);
    else if (OPTION("-xt"))   xt = atoi(ARGUMENT);
    else if (OPTION("-yt"))   yt = atoi(ARGUMENT);
    else if (OPTION("-zt"))   zt = atoi(ARGUMENT);
    else if (OPTION("-tt"))   tt = atoi(ARGUMENT);
    else if (OPTION("-x"))    xf = xt = atoi(ARGUMENT);
    else if (OPTION("-y"))    yf = yt = atoi(ARGUMENT);
    else if (OPTION("-z"))    zf = zt = atoi(ARGUMENT);
    else if (OPTION("-t"))    tf = tt = atoi(ARGUMENT);
    else if (OPTION("-xyz"))  xf = xt = yf = yt = zf = zt = atoi(ARGUMENT);
    else if (OPTION("-xyzt")) xf = xt = yf = yt = zf = zt = tf = tt = atoi(ARGUMENT);
    else HANDLE_COMMON_OR_UNKNOWN_OPTION();
  }
  
  if(xf==0 && yf==0 && zf==0 && tf==0 && xt==0 && yt==0 && zt==0 && tt==0) FatalError("No extension specified!");

  // Read labels from input image
  RealImage input;
  input.Read(input_image_name);

  // Create output image by extending the input image
  ImageAttributes attr = input.Attributes();
  ImageAttributes newattr(attr);

  if(xf){ newattr._x += xf; newattr._xorigin += xf*attr._dx*0.5; }
  if(yf){ newattr._y += yf; newattr._yorigin += yf*attr._dy*0.5; }
  if(zf){ newattr._z += zf; newattr._zorigin += zf*attr._dz*0.5; }
  if(tf){ newattr._t += tf; newattr._torigin += tf*attr._dt*0.5; }
  if(xt){ newattr._x += xt; newattr._xorigin -= xt*attr._dx*0.5; }
  if(yt){ newattr._y += yt; newattr._yorigin -= yt*attr._dy*0.5; }
  if(zt){ newattr._z += zt; newattr._zorigin -= zt*attr._dz*0.5; }
  if(tt){ newattr._t += tt; newattr._torigin -= tt*attr._dt*0.5; }
  
  RealImage output(newattr);
  if(value != 0){
    for (int i = 0; i < output.GetNumberOfVoxels(); ++i)
      output.Put(i, value);
  }
    
  int ni, nj, nk, nl;
  for (int l = 0; l < input.T(); ++l)
  for (int k = 0; k < input.Z(); ++k)
  for (int j = 0; j < input.Y(); ++j)
  for (int i = 0; i < input.X(); ++i) {
    ni = i+xf;
    nj = j+yf;
    nk = k+zf;
    nl = l+tf;
    if(ni<0 || nj<0 || nk<0 || nl<0 || ni>=output.X() || nj>=output.Y() || nk>=output.Z() || nl>=output.T()) continue;
    output.Put(ni, nj, nk, nl, input.Get(i, j, k, l));
  }

  // Write output image
  output.Write(output_image_name);
  
  return 0;
}

