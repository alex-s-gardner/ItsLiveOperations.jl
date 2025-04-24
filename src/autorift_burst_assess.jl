# point to the directory containing the test .json files

testdir = "/Users/gardnera/data/its-live-working/tests/burst_processing";

# install the necessary packages if they are not already installed
#using Pkg; Pkg.add(["STAC", "CairoMakie", "Downloads", "NCDatasets", "HTTP", "Proj", "GeometryOps", "Extents", "GeoInterface", "Dates", "JSON", "Rasters",  "FileIO"])

# import the necessary packages
begin
    using STAC
    using CairoMakie
    using Downloads
    using NCDatasets
    using HTTP
    using Proj
    using Extents
    using Dates
    using JSON
    using Rasters
    using Extents
    using FileIO

    import GeoInterface as GI
    import GeometryOps as GO
    import ArchGDAL
    include("utilities.jl")
end;

# get the list of json files in the test directory
path2alljson = filter(x -> endswith(x, ".json"), readdir(testdir))

# loop through the json files, create analysis figure for each granule, plot and save.
for path2json in path2alljson[5:end]
#path2json = path2alljson[4]
    # read in run info from json file
    jobinfo = JSON.parse(read(joinpath(testdir, path2json), String));

    figure_dir = joinpath(testdir, "figures", split(splitpath(path2json)[end], ".")[1])
    if !isdir(figure_dir)
        mkdir(figure_dir)
    end

    for info in jobinfo
    #info = jobinfo[39]
        # get the path to a single granule
        if info["status_code"] == "FAILED"
            continue
        end

        paths2granule = info["files"][1]["url"]

        # download the granule
        local_path = local_copy(paths2granule);

        # read in the granule as a RasterStack
        new_granule = RasterStack(local_path);
        lon_center = new_granule[:img_pair_info].metadata["longitude"]
        lat_center = new_granule[:img_pair_info].metadata["latitude"]

        for attempt = 1:3
            try
                search_results = collect(itslive_stac_search(new_granule))
                break
            catch e
                (attempt == 3) && throw(e)
                sleep(5)
            end
        end

        if isempty(search_results)
            continue
        end

        old_granule = String[]
        for result in search_results
            url2nc = result.assets["data"].data.href
            path2nc = push!(old_granule,local_copy(url2nc))
        end

        itslive_filepaths = itslive_paramfiles(lon_center, lat_center)
        path2land = local_copy(itslive_filepaths["StableSurface"])

        land = Raster(path2land; lazy = true)
        land = resample(land; to=new_granule)
        land = (land .== 1) .& .!ismissing.(land)

        f = Figure(size=(2000, 1500))
        Label(f[1, 1:2, Top()], splitpath(local_path)[end], padding = (0, 0, 0, 0), fontsize=22)

        varname = "v"
        old_variable = Raster.(old_granule; name=varname)
        old_variable = mosaic(last, old_variable)
        old_variable = resample(old_variable; to=new_granule)

        ax = Axis(f[1, 1])
        heatmap!(ax, log.(old_variable), colorrange=(0, 10))
        hidedecorations!(ax)
        hidespines!(ax) 
        text!(ax, 0.5, 0.5, text = "$(varname) [old]", align = (:center, :center), space = :relative, fontsize = 80)


        ax = Axis(f[2, 1])
        heatmap!(ax, log.(new_granule[varname]), colorrange=(0, 10))
        hidedecorations!(ax)
        hidespines!(ax) 
        text!(ax, 0.5, 0.5, text = "$(varname) [new]", align = (:center, :center), space = :relative, fontsize = 80)

        
        for (i, varname) in enumerate(["vx", "vy"])

            path2refvel = local_copy(itslive_filepaths[varname])
            refvel = Raster(path2refvel; lazy = true)
            refvel = resample(refvel; to=new_granule)

            old_variable = Raster.(old_granule; name=varname)
            old_variable = mosaic(last, old_variable)
            old_variable = resample(old_variable; to=new_granule)

            all_valid = land .& .!ismissing.(new_granule[varname]) .& .!ismissing.(old_variable) .& .!ismissing.(refvel)

            if !any(all_valid)
                continue
            end

            ax = Axis(f[i, 2], ylabel="count", xlabel="$(varname) minus reference $(varname) over stable surface [m/yr]")
            v1 = parent(old_variable)[all_valid] .- parent(refvel)[all_valid];
            v2 = parent(new_granule[varname])[all_valid] .- parent(refvel)[all_valid];

            q = round.(Int, quantile(vcat(v1, v2), [0.01, 0.99]))
            hist!(ax, v1; bins=q[1]:1:q[2], label="old [$(round(Int, median(v1))) ± $(round(Int, std(v1))) m/yr]")
            hist!(ax, v2; bins =q[1]:1:q[2], label="new [$(round(Int, median(v2))) ± $(round(Int, std(v2))) m/yr]")
            axislegend()
        end
        display(f)

        outfile = joinpath(figure_dir, split(splitpath(local_path)[end], ".")[1] * ".png")
        save(outfile, f)
    end
end
