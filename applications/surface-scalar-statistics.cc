#include "mirtk/Common.h"
#include "mirtk/Options.h"

#include "mirtk/PointSetIO.h"
// #include "mirtk/PointSetUtils.h"

#include <vtkSmartPointer.h>
#include <vtkPolyData.h>
#include <vtkTriangle.h>
#include <vtkIdList.h>
#include <vtkPolyDataReader.h>
#include <vtkFloatArray.h>
#include <vtkPointData.h>

#include <algorithm> 
#include <vector>
#include <set>


using namespace std;
using namespace mirtk;

// =============================================================================
// Help
// =============================================================================

// -----------------------------------------------------------------------------
void PrintHelp(const char *name)
{
  cout << endl;
  cout << "Usage: " << name << " <input> <options>" << endl;
  cout << endl;
  cout << "Calculates statistics on the scalars of surface <input>." << endl;
  cout << endl;
  cout << "Optional arguments:" << endl;
  cerr << " -q                          Give the same output as normal but just the " << endl;
  cerr << "                             numbers on a space separated line." << endl;
  cerr << " -name <name>                Name of scalars for which stats are required." << endl;
  cerr << " -mask <name> <val1>..<valN> Name of scalars to use as a mask," << endl;
  cerr << "                             stats only calculated where mask value is = mask_val." << endl;
  cerr << " -maskgt <name] <val>        Name of scalars to use as a mask," << endl;
  cerr << "                             stats only calculated where mask value is > mask_val." << endl;
  cerr << " -masklt <name> <val>        Name of scalars to use as a mask," << endl;
  cerr << "                             stats only calculated where mask value is < mask_val." << endl;
  cerr << " -sign <-1/1>                use only positive(1)/negative(-1) values." << endl;
  cerr << " " << endl;
  cerr << " " << endl;
  PrintStandardOptions(cout);
  cout << endl;
}

// =============================================================================
// Main
// =============================================================================

// -----------------------------------------------------------------------------
int main(int argc, char **argv)
{
  REQUIRES_POSARGS(1);

  char *input_name = NULL;
  char *scalar_name = NULL;
  char *mask_name = NULL;

  double sum, sumSq, sumAbs;
  int i;
  int noOfPoints, count;
  double minVal, maxVal;
  double mean, var, sd, val;
  double meanSq, meanAbs, varAbs, sdAbs;
  int quiet = false;

  // For weighting by cell area.
  vtkTriangle *triangle;
  vtkIdType *cells;
  unsigned short noOfCells;
  int k;
  vtkIdList *ptIds;
  double v1[3], v2[3], v3[3], triangleArea;
  double totalArea;
  totalArea = 0.0;
  double integral = 0.0;
  int	nonTriangleFaces = 0;
  int mask_val;
  bool maskgt=false, masklt=false;
  set<int> mask_vals;

  // Parse image
  input_name  = POSARG(1);
  int sign=0;
  // Parse remaining arguments

  for (ALL_OPTIONS) {
    if      (OPTION("-q")) quiet = true;
    else if (OPTION("-name")) scalar_name = ARGUMENT;
    else if (OPTION("-sign")) PARSE_ARGUMENT(sign);
    else if (OPTION("-mask")){
      mask_name = ARGUMENT;
      do {
        PARSE_ARGUMENT(mask_val);
        mask_vals.insert(mask_val);
      } while (HAS_ARGUMENT);
    }
    else if (OPTION("-maskgt")){
      maskgt = true;
      mask_name = ARGUMENT;
      PARSE_ARGUMENT(mask_val);
    }
    else if (OPTION("-masklt")){
      masklt = true;
      mask_name = ARGUMENT;
      PARSE_ARGUMENT(mask_val);
    }
    else HANDLE_COMMON_OR_UNKNOWN_OPTION();
  }

  // Read surface
  vtkSmartPointer<vtkPolyData> input = ReadPolyData(input_name);

  input->BuildCells();
  input->BuildLinks();

  noOfPoints= input->GetNumberOfPoints();

  vtkFloatArray *scalars;// = vtkFloatArray::New();
  int ind;

  if (scalar_name == NULL){
    scalars = (vtkFloatArray*) input->GetPointData()->GetScalars();
    if (scalars == NULL){
      cerr << "No scalars available." << endl;
      exit(1);
    }
  } else {
    scalars = (vtkFloatArray*) input->GetPointData()->GetArray(scalar_name, ind);

    if (ind == -1 || scalars == NULL){
      cerr << "Scalars unavailable with name " << scalar_name << endl;
      exit(1);
    }
  }

  int *mask = new int[noOfPoints];
  for (i = 0; i < noOfPoints; ++i){
  	mask[i] = 1;
  }

  if (mask_name != NULL){
    vtkFloatArray *mask_scalars = (vtkFloatArray*) input->GetPointData()->GetArray(mask_name, ind);
    if (ind == -1 || mask_scalars == NULL){
      cerr << "Masking scalars unavailable with name " << mask_name << endl;
      exit(1);
    }
    if (mask_scalars->GetNumberOfComponents() > 1){
    	cerr << "Masking scalars " << mask_scalars->GetName() << " has more than one component." << endl;
    	exit(1);
    }

    for (i = 0; i < noOfPoints; ++i){
      if(maskgt){
        if (mask_scalars->GetTuple1(i) <= mask_val)
           mask[i] = 0;
      }else if(masklt){
        if (mask_scalars->GetTuple1(i) >= mask_val)
           mask[i] = 0;
      }else{
        if (mask_vals.find(mask_scalars->GetTuple1(i)) == mask_vals.end())
           mask[i] = 0;
      }
    }

  }

  if (scalars->GetNumberOfComponents() > 1){
  	cerr << "Scalars " << scalars->GetName() << " has more than one component." << endl;
  	exit(1);
  }

  sum = 0.0;
  sumSq = 0.0;
  sumAbs = 0.0;
  minVal = FLT_MAX;
  maxVal = -1 * minVal;

  count = 0;

  vector<double> vals;
  for (i = 0; i < noOfPoints; ++i){
    if (mask[i] <= 0) continue;
    val = scalars->GetTuple1(i);

    if(sign>0 && val<=0) continue;
    if(sign<0 && val>=0) continue;
  	
    ++count;
    vals.push_back(val);

    sum += val;
    sumSq += val*val;
    sumAbs += fabs(val);
    if (minVal > val)
      minVal = val;
    if (maxVal < val)
      maxVal = val;

    input->GetPointCells(i, noOfCells, cells);

    if ( cells == NULL )
      continue;

    for (k = 0; k < noOfCells; ++k){
      triangle = vtkTriangle::SafeDownCast(input->GetCell(cells[k]));

      if ( triangle != NULL ){
        ptIds = triangle->GetPointIds();

        input->GetPoint(ptIds->GetId(0), v1);
        input->GetPoint(ptIds->GetId(1), v2);
        input->GetPoint(ptIds->GetId(2), v3);

	//the area of the triangle volume) contributes by 1/3 to each point of the triangle
        triangleArea = vtkTriangle::TriangleArea(v1, v2, v3) / 3.0;
        integral += triangleArea * val;
        totalArea += triangleArea;

      } else {
      	++nonTriangleFaces;
      }

    }
  }

  if (count < 1){
  	cerr << "Zero points remain after masking, exiting " << endl;
  	exit(0);
  }

  mean    = sum / ((double) count);
  meanSq  = sumSq / ((double) count);
  meanAbs = sumAbs / ((double) count);

  var = meanSq - (mean*mean);
  sd  = sqrt(var);

  varAbs = meanSq - (meanAbs*meanAbs);
  sdAbs  = sqrt(varAbs);

  // Normalisation based on the area of a sphere. Becomes an L2 norm if input stat is a squared measurement.
  double normedIntegral = sqrt(integral / 4.0 / M_PI);
  double sqrtIntegral = sqrt(integral);
  double avgIntegral=integral/totalArea;
  
  sort( vals.begin(), vals.end() );
  double median= vals[floor(vals.size()/2)];




  if (quiet){
    //cout << ""  << scalars->GetName();
    cout << noOfPoints;
    cout << " " << count;
    cout << " " << median;
    cout << " " << mean;
    cout << " " << meanSq;
    cout << " " << sd;
    cout << " " << meanAbs;
    cout << " " << sdAbs;
    cout << " " << minVal << " " << maxVal;
    cout << " " << totalArea << endl;
    cout << " " << avgIntegral<< endl;
    cout << " " << integral;
    cout << " " << sqrtIntegral << endl;
    cout << " " << normedIntegral << endl;
  } else {
    cout << "Scalar name         : " << scalars->GetName() << endl;
    cout << "Number of points    : " << noOfPoints << endl;
    cout << "After masking       : " << count << endl;
    cout << "Median              : " << median << endl;
    cout << "Mean                : " << mean << endl;
    cout << "Mean Sq             : " << meanSq << endl;
    cout << "S.D.                : " << sd << endl;
    cout << "Mean(abs)           : " << meanAbs << endl;
    cout << "S.D(abs)            : " << sdAbs << endl;
    cout << "Min/Max             : " << minVal << " " << maxVal << endl;
    cout << "Area                : " << totalArea << endl;
    cout << "int                 : " << avgIntegral << endl;
    cout << "Area int            : " << integral << endl;
    cout << "sqrt(Area int)      : " << sqrtIntegral << endl;
    cout << "sqrt(Area int/4 pi) : " << normedIntegral << endl;
    if (nonTriangleFaces > 0)
     cout << "Non Triangle Faces  : " << nonTriangleFaces << endl;
    cout << "" << "" << endl;
  }

  delete [] mask;
  return 0;
}

