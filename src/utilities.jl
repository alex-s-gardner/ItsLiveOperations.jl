"""
    local_copy(remote_path)

Downloads a file from the given URL to a temporary directory if it doesn't already exist locally.

# Arguments
- `remote_path`: URL or path to the image file to be downloaded.

# Returns
- `local_path`: Path to the local copy of the file in the temporary directory.
"""
function local_copy(remote_path)
    local_path = joinpath(tempdir(), splitpath(remote_path)[end])

    if !isfile(local_path)
        Downloads.download(remote_path, local_path)
    end
    return local_path
end


"""
    extent2rectangle(extent)

Converts an extent to a GeoInterface polygon rectangle.

# Arguments
- `extent`: An array-like object where the first element contains x-bounds [min_x, max_x] 
  and the second element contains y-bounds [min_y, max_y].

# Returns
- A GeoInterface Polygon representing a rectangle with vertices at the corners of the extent.
"""
function extent2rectangle(extent)
    xbounds = extent[1]
    ybounds = extent[2]
    rectangle = GI.Wrappers.Polygon([[(xbounds[1], ybounds[1]), (xbounds[1], ybounds[2]), (xbounds[2], ybounds[2]), (xbounds[2], ybounds[1]), (xbounds[1], ybounds[1])]])
    return rectangle
end


# given a Raster of an its_live granule, return a STAC search for overlapping granules with the same date
function itslive_stac_search(rs::RasterStack; endpoint="https://stac.itslive.cloud", collections="itslive-granules")

    # get the source and target crs
    source_crs = "EPSG:$(Rasters.metadata(rs[:v])["grid_mapping"]["spatial_epsg"])"

    # specify the target crs for polygon
    target_crs = "EPSG:4326"

    extent = extent2rectangle(Rasters.extent(rs))
    extent = GO.reproject(extent, source_crs, target_crs, always_xy=true)
    extent = GI.extent(extent)


    date_center = DateTime(rs[:img_pair_info].metadata["date_center"][1:17], "yyyymmddTHH:MM:SS")
    date_dt = rs[:img_pair_info].metadata["date_dt"]

   
    # this should not need to be wrapped in an array

    time_range = (date_center - Second(1), date_center + Second(1)) # start and end time

    filter1 = Dict(
        "op" => "and",
        "args" => [
            Dict(
                "op" => "<=",
                "args" => [Dict("property" => "dt_days"), date_dt + 0.001]
            ),
            Dict(
                "op" => ">=",
                "args" => [Dict("property" => "dt_days"), date_dt - 0.001]
            )
        ]
    )

    catalog = STAC.Catalog(endpoint)

    stac_search = search(catalog, collections, extent.X, extent.Y, time_range; filter=filter1)

    return stac_search
end



"""
    itslive_zone(lon, lat; always_xy = true)
Return the utm `zone` and `isnorth` variables for the ITS_LIVE projection
"""
function itslive_zone(lon, lat; always_xy=true)
    if !always_xy
        lat, lon = (lon, lat)
    end

    # check for invalid conditions and return zone = -1
    if isnan(lon) || isnan(lat)
        return (-1, false)
    end


    if lat > 55
        return (0, true)
    elseif lat < -56
        return (0, false)
    end

    # int versions
    ilon = floor(Int64, Geodesy.bound_thetad(lon))

    # zone
    zone = fld((ilon + 186), 6)

    isnorth = lat >= 0
    return (zone, isnorth)
end

"""
    itslive_paramfiles(lon, lat; gridsize = 240, path2param = "/Users/...", always_xy = true)
Return paths to its_live parameter files
"""
function itslive_paramfiles(
    lon,
    lat;
    gridsize=240,
    path2param=paths["itslive_parameters"],
    always_xy=true)

    zone, isnorth = itslive_zone(lon, lat; always_xy=always_xy)

    if isnorth
        if zone == 0
            region = "NPS"
        else
            region = @sprintf("N%02.0f", zone)
        end
    else
        if zone == 0
            region = "SPS"
        else
            region = @sprintf("S%02.0f", zone)
        end
    end

    grid = @sprintf("%04.0fm", gridsize)

    paramfiles = Dict(
        "ROI" => joinpath(path2param, "$(region)_$(grid)_ROI.tif"), 
        "StableSurface" => joinpath(path2param, "$(region)_$(grid)_StableSurface.tif"), 
        "dhdx" => joinpath(path2param, "$(region)_$(grid)_dhdx.tif"), 
        "dhdxs" => joinpath(path2param, "$(region)_$(grid)_dhdxs.tif"), 
        "dhdy" => joinpath(path2param, "$(region)_$(grid)_dhdy.tif"), 
        "dhdys" => joinpath(path2param, "$(region)_$(grid)_dhdys.tif"), 
        "FloatingIce" => joinpath(path2param, "$(region)_$(grid)_FloatingIce.tif"), 
        "GlacierIce" => joinpath(path2param, "$(region)_$(grid)_GlacierIce.tif"), 
        "h" => joinpath(path2param, "$(region)_$(grid)_h.tif"), 
        "inlandwater" => joinpath(path2param, "$(region)_$(grid)_inlandwater.tif"), 
        "land" => joinpath(path2param, "$(region)_$(grid)_land.tif"), 
        "landice" => joinpath(path2param, "$(region)_$(grid)_landice.tif"), 
        "landice_2km_inbuff" => joinpath(path2param, "$(region)_$(grid)_landice_2km_inbuff.tif"), 
        "ocean" => joinpath(path2param, "$(region)_$(grid)_ocean.tif"), 
        "region" => joinpath(path2param, "$(region)_$(grid)_region.tif"), 
        "sp" => joinpath(path2param, "$(region)_$(grid)_sp.tif"), 
        "thickness" => joinpath(path2param, "$(region)_$(grid)_thickness.tif"), 
        "vx" => joinpath(path2param, "$(region)_$(grid)_vx.tif"), 
        "vx0" => joinpath(path2param, "$(region)_$(grid)_vx0.tif"), 
        "vxSearchRange" => joinpath(path2param, "$(region)_$(grid)_vxSearchRange.tif"), 
        "vy" => joinpath(path2param, "$(region)_$(grid)_vy.tif"), 
        "vy0" => joinpath(path2param, "$(region)_$(grid)_vy0.tif"), 
        "vySearchRange" => joinpath(path2param, "$(region)_$(grid)_vySearchRange.tif"), 
        "xMaxChipSize" => joinpath(path2param, "$(region)_$(grid)_xMaxChipSize.tif"), 
        "xMinChipSize" => joinpath(path2param, "$(region)_$(grid)_xMinChipSize.tif"), 
        "yMaxChipSize" => joinpath(path2param, "$(region)_$(grid)_yMaxChipSize.tif"), 
        "yMinChipSize" => joinpath(path2param, "$(region)_$(grid)_yMinChipSize.tif"), 
    )

    return paramfiles
end
