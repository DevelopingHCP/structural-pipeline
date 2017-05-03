// =============================================================================
// Project: Image Registration Toolkit (IRTK)
// Package: PolyData
// =============================================================================


#include "mirtk/Common.h"
#include "mirtk/Options.h"

#include "mirtk/IOConfig.h"
#include "mirtk/GenericImage.h"

#include "mirtk/EuclideanDistanceTransform.h"
#include "mirtk/GaussianBlurring.h"

#include <map>
#include <queue>

using namespace std;
using namespace mirtk;
// =============================================================================
// Help
// =============================================================================

// -----------------------------------------------------------------------------
void PrintHelp(const char *name)
{
  cout << "usage:  " << name << " <input> <output>" << endl;
  cout << endl;
  cout << "Assign labels to the whole extent of the image according to the distance from the original labels." << endl;
  cout << endl;
  cout << "Optional arguments:" << endl;
  cout << "  -blur <sigma>                blurs the distance maps using sigma" << endl;
  PrintStandardOptions(cout);
  cout << endl;
}

// =============================================================================
// Types
// =============================================================================

typedef GenericImage<short>                LabelImage;
typedef map<short, long>                   CountMap;
typedef CountMap::const_iterator           CountIter;
typedef set<short>                         LabelSet;
typedef LabelSet::const_iterator           LabelIter;
typedef EuclideanDistanceTransform<double> DistanceTransform;

// =============================================================================
// Auxiliaries
// =============================================================================

// -----------------------------------------------------------------------------
/// Returns a floating point 0/1 image to show a label.  The image needs to
/// be floating point so that it can later be used in a distance map filter.
void InitializeLabelMask(const LabelImage &labels, RealImage &mask, short label)
{
  const int noOfVoxels = labels.NumberOfVoxels();

  double        *ptr2mask   = mask.Data();
  const short *ptr2labels = labels.Data();

  for (int i = 0; i < noOfVoxels; ++i, ++ptr2mask, ++ptr2labels) {
    *ptr2mask = static_cast<float>(*ptr2labels == label);
  }
}

// -----------------------------------------------------------------------------
LabelImage DilateLabels(const LabelImage &labels, double blursigma)
{
  // Count up different labels so we can identify the number of distinct labels.
  CountMap labelCount;
  const int noOfVoxels = labels.NumberOfVoxels();
  const GreyPixel *ptr2label  = labels.Data();
  for (int i = 0; i < noOfVoxels; ++i, ++ptr2label) {
    if (*ptr2label > 0) ++labelCount[*ptr2label];
  }
  const int noOfLabels = static_cast<int>(labelCount.size());

  if (verbose) {
    cout << "No. of voxels        = " << noOfVoxels << endl;
    if (verbose > 1) {
      cout << "Label Counts " << endl;
      for (CountIter iter = labelCount.begin(); iter != labelCount.end(); ++iter) {
        cout << iter->first << "\t" << iter->second << endl;
      }
    }
    cout << "No. of labels        = " << noOfLabels << endl;
  }

  // Using the distance maps.
  RealImage minDmap(labels.Attributes());
  RealImage curDmap(labels.Attributes());
  RealImage curMask(labels.Attributes());

  // Initialise the minimum distance map.
  minDmap = numeric_limits<RealPixel>::max();

  // Note that the dilated labels are initialised to the given label image.
  // I.e. the original labels are left alone and we seek to assign labels to
  // the zero voxels based on closest labeled voxels.
  LabelImage dilatedLabels = labels;

  // Single distance transform filter for all labels.
  DistanceTransform edt(DistanceTransform::DT_3D);

  if (verbose) {
    cout << "Finding distance maps ";
    if (verbose > 1) cout << "...\nCurrent label =";
  }
  int niter = 0;
  for (CountIter iter = labelCount.begin(); iter != labelCount.end(); ++iter, ++niter) {
    const short &curLabel = iter->first;
    if (verbose == 1) {
      if (niter > 0 && niter % 65 == 0) cout << "\n               ";
      cout << '.';
      cout.flush();
    } else if (verbose > 1) {
      if (niter > 0 && niter % 20 == 0) cout << "\n               ";
      cout << " " << curLabel;
      cout.flush();
    }

    // There is a new operator used for currLabelMask in the following function call.
    InitializeLabelMask(labels, curMask, curLabel);

    edt.Input (&curMask);
    edt.Output(&curDmap);
    edt.Run();
    
    if (blursigma>0){
		// Blur image
		GaussianBlurring<double> gaussianBlurring(blursigma);
		gaussianBlurring.Input (&curDmap);
		gaussianBlurring.Output(&curDmap);
		gaussianBlurring.Run();
    }

    double        *ptr2minDmap      = minDmap.Data();
    double        *ptr2dmap         = curDmap.Data();
    const short *ptr2label        = labels.Data();
    short       *ptr2dilatedLabel = dilatedLabels.Data();

    for (int i = 0; i < noOfVoxels; ++i, ++ptr2minDmap, ++ptr2dmap, ++ptr2label, ++ptr2dilatedLabel) {
      if (*ptr2label == 0 && *ptr2dmap < *ptr2minDmap) {
        *ptr2minDmap      = *ptr2dmap;
        *ptr2dilatedLabel = curLabel;
      }
    }
  }
  if (verbose) {
    if (verbose > 1) cout << "\nFinding distance maps ...";
    cout << " done" << endl;
  }
  return dilatedLabels;
}
// =============================================================================
// Main
// =============================================================================

int main(int argc, char **argv)
{
  // Positional arguments
  REQUIRES_POSARGS(2);
  verbose=true;
  InitializeIOLibrary();
  
  const char *input_image_name   = POSARG(1);
  const char *output_label_image_name  = POSARG(2);
  
  double blursigma = 0;
  for (ALL_OPTIONS) {
    if (OPTION("-blur"))   blursigma = atof(ARGUMENT);
    else HANDLE_COMMON_OR_UNKNOWN_OPTION();
  }
  
  // Read labels from input image
  GreyImage labels;
  if (input_image_name) {
    if (verbose) cout << "Reading labels ...", cout.flush();
    labels.Read(input_image_name);
    if (verbose) cout << " done" << endl;
  }

  // Compute dilated labels
  LabelImage dilatedLabels;
  dilatedLabels = DilateLabels(labels, blursigma);
  if (output_label_image_name) dilatedLabels.Write(output_label_image_name);
  
  return 0;
}

