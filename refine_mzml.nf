/*
==============================
MZML REFINER PIPELINE
==============================
For when you have discovered you have systematic errors (i.e. global m/z shifts) in your
spectra.

@Authors
Jorrit Boekel @glormph
*/


params.isobaric = false
params.activation = 'hcd'
params.outdir = 'results'
params.tdb = false
params.instrument = false
params.pwizcontainer = 'quay.io/biocontainers/proteowizard:3_0_9992--h2d50403_2'

if (params.isobaric) {
  mods = file([itraq8plex: "${baseDir}/data/itraq8mods.txt", itraq4plex: "${baseDir}/data/itraq4mods.txt", tmt10plex: "${baseDir}/data/tmtmods.txt", tmt6plex: "${baseDir}/data/tmtmods.txt"][params.isobaric])
} else {
  mods = file("${baseDir}/data/labelfreemods.txt")
}
plextype = params.isobaric ? params.isobaric.replaceFirst(/[0-9]+plex/, "") : 'false'
msgfprotocol = [tmt:4, itraq:2, false:0][plextype]
instrument = params.instrument ? params.instrument : false
msgfinstrument = [velos:1, qe:3, false:0][instrument]


/* input is mzmldef file, tsv:
mzML\tfn_id\n
*/

Channel
  .from(file("${params.mzmldef}").readLines())
  .map { it -> it.tokenize('\t') }
  .map { it -> [file(it[0]), file(it[0]).baseName.replaceFirst(/.*\/(\S+)\.mzML/, "\$1"), it[1]] } // file, samplename, fn_dbid
  .set { mzml_msgf }


process msgfPlus {

  input:
  set file(x), val(sample), val(dbid) from mzml_msgf
  file('tdb.fa') from Channel.fromPath(params.tdb)
  file mods

  output:
  set file(x), val(sample), file("search.mzid"), val(dbid) into mzml_mzid
  
  """
  msgf_plus -Xmx16g -d tdb.fa -s "$x" -o search.mzid -thread 12 -mod $mods -tda 0 -t 50.0ppm -ti -1,2 -m 0 -inst ${msgfinstrument} -e 1 -protocol ${msgfprotocol} -ntt 2 -minLength 7 -maxLength 50 -minCharge 2 -maxCharge 6 -n 1 -addFeatures 1
  rm tdb.c*
  """
}

process mzRefine {
  container params.pwizcontainer

  publishDir "${params.outdir}", mode: 'copy', overwrite: true

  input:
  set file(mzml), val(sample), file("${sample}.mzid"), val(dbid) from mzml_mzid

  output:
  file("${dbid}___${sample}_refined.mzML")

  """
  msconvert $mzml --outfile ${dbid}___${sample}_refined.mzML --filter "mzRefiner ${sample}.mzid thresholdValue=-1e-10 thresholdStep=10 maxSteps=2 thresholdScore=SpecEValue"
  """
}
