# ItsLiveOperations.jl

A project operations Julia package for working with ITS_LIVE (The Inter-mission Time Series of Land Ice Velocity and Elevation) data products and operations.

## Overview

ItsLiveOperations.jl provides tools and utilities for:
- Downloading and managing ITS_LIVE data products
- Accessing ITS_LIVE STAC catalog
- Processing and analyzing ice velocity data
- Working with ITS_LIVE parameter files and regional data
- Performing spatial operations and coordinate transformations

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/alex-s-gardner/ItsLiveOperations.jl")
```

## Dependencies

The package requires several Julia packages:
- STAC
- CairoMakie
- NCDatasets
- HTTP
- Proj
- GeometryOps
- GeoInterface
- Rasters
- JSON
- FileIO
- ArchGDAL

## Key Features


## Usage Examples


# autorift_burst_assess.jl

This script assesses AutoRIFT burst processing results by analyzing test JSON files
containing burst processing information. It downloads and analyzes granules, searches
for results using the ITS_LIVE STAC API, and generates analysis figures for each granule.

The script compares new granules with existing ones and reference velocity data over stable
surfaces, creating visualizations to evaluate the quality of the burst processing results.

Workflow
1. Reads test JSON files containing burst processing information
2. Downloads and analyzes granules for each test case
3. Searches for existing results using the ITS_LIVE STAC API
4. Compares new granules with existing ones and reference velocity data
5. Generates analysis figures showing velocity magnitudes and differences
6. Saves figures for each granule in a designated directory


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT license

## Acknowledgments

This package interfaces with data from the NASA MEaSUREs ITS_LIVE project.
