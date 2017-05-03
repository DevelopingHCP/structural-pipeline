// =============================================================================
// Project: Image Registration Toolkit (IRTK)
// Package: Registration
//
// Copyright (c) 2015 Imperial College London
// Copyright (c) 2015 Andreas Schuh
// =============================================================================

// =============================================================================
// Includes
// =============================================================================

#include "mirtk/Common.h"
#include "mirtk/Options.h"

#include "mirtk/PointSetIO.h"
#include "mirtk/PointSetUtils.h"

#include "vtkSmartPointer.h"
#include "vtkPolyData.h"
#include "vtkPointData.h"
#include "vtkCellData.h"
#include "vtkDataArray.h"
#include "vtkFloatArray.h"
#include "vtkPolyDataNormals.h"
#include "vtkImplicitModeller.h"
#include "vtkContourFilter.h"
#include "vtkPolyDataConnectivityFilter.h"
#include "vtkCellLocator.h"
#include "vtkMath.h"
#include "vtkQuadricDecimation.h"

using namespace std;
using namespace mirtk;

// =============================================================================
// Help
// =============================================================================

// -----------------------------------------------------------------------------
void PrintHelp(const char *name)
{
  cout << endl;
  cout << "Usage: " << name << " <input1> <input2> <output>" << endl;
  cout << endl;
  cout << "Calculates the middle surface between surface input1 and surface input2." << endl;
  cout << endl;
  cout << "Optional arguments:" << endl;
  cout << "  -ascii                       vtk ascii format" << endl;
  cout << "  -compress                    vtk compress" << endl;
  PrintStandardOptions(cout);
  cout << endl;
}

// =============================================================================
// Main
// =============================================================================

// -----------------------------------------------------------------------------
int main(int argc, char **argv)
{
  // Parse arguments
  REQUIRES_POSARGS(3);

  const char *input_name1  = POSARG(1);
  const char *input_name2  = POSARG(2);
  const char *output_name  = POSARG(3);
  
  FileOption fopt = FO_Default;
  for (ALL_OPTIONS) {
    HANDLE_POINTSETIO_OPTION(fopt);
    else HANDLE_COMMON_OR_UNKNOWN_OPTION();
  }
  
  vtkSmartPointer<vtkPolyData> polydata1 = ReadPolyData(input_name1);
  vtkSmartPointer<vtkPolyData> polydata2 = ReadPolyData(input_name2);
 
  // Make shallow output to not modify/add normals of/to input surface
  vtkSmartPointer<vtkPolyData> output;
  output = vtkSmartPointer<vtkPolyData>::New();
  output->DeepCopy(polydata1);
  
  // Move points of input surface mesh
  double p[3], p2[3], n[3];
  vtkPoints *points1 = polydata1->GetPoints();
  vtkPoints *points2 = polydata2->GetPoints();
  vtkPoints *points = output->GetPoints();

  for (vtkIdType ptId = 0; ptId < points->GetNumberOfPoints(); ++ptId) {
	points1->GetPoint(ptId, p);
	points2->GetPoint(ptId, p2);
	for(int i=0;i<3;i++){ 
		n[i] = (p[i]+p2[i]) / 2;
    }
	points->SetPoint(ptId, n);
  }

  // Write output surface mesh
  if (!WritePolyData(output_name, output, fopt)) {
    cerr << "Error: Failed to write offset surface to " << output_name << endl;
    exit(1);
  }

  return 0;
}
