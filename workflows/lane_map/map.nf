params.bwaMemOptions = "-k 20 -w 105 -d 105 -r 1.3 -c 12000 -A 1 -B 4 -O 6 -E 1 -L 6 -U 18 -Y -K 100000000"

include { BWA_SAMSE } from '../../modules/lane_map/bwa_samse.nf'
include { BWA_SAMPE } from '../../modules/lane_map/bwa_sampe.nf'
include { BWA_MEM_SE } from '../../modules/lane_map/bwa_mem_se.nf'
include { BWA_MEM_PE } from '../../modules/lane_map/bwa_mem_pe.nf'
include { PICARD_CLEAN_SAM } from '../../modules/lane_map/picard_clean_sam.nf'


workflow MAP {
    take:
        // Queue Channel containing tuples of flowCell lane library information
        // [fastq1, fastq2, flowCell, lane, library, sampleId, userId, readGroup, readLength, readType, publishDirectory]
        ch_flowCellLaneLibraryTuple

        // Groovy objects
        referenceGenome

    main:
    def ch_referenceGenome = Channel.value(referenceGenome)
    def ch_bwaMemOptions = Channel.value(params.bwaMemOptions)

    ch_flowCellLaneLibraryTuple.branch { fastq1, fastq2, flowCell, lane, library, sampleId, userId, readGroup, readLength, readType, publishDirectory ->
        samse: (readType == 'SR' || readType == 'SE') && readLength < 75
        memse: (readType == 'SR' || readType == 'SE') && readLength >= 75
        sampe: readType == 'PE' && readLength < 75
        mempe: readType == 'PE' && readLength >= 75
        badReadType: true
    }
    | set { ch_branchedFlowCellLaneLibraries }

    def mapToSingleRead = {fastq1, fastq2, flowCell, lane, library, sampleId, userId, readGroup, readLength, readType, publishDirectory -> [fastq1, flowCell, lane, library, sampleId, userId, readGroup, publishDirectory]}
    def mapToPairedEnd = {fastq1, fastq2, flowCell, lane, library, sampleId, userId, readGroup, readLength, readType, publishDirectory -> [fastq1, fastq2, flowCell, lane, library, sampleId, userId, readGroup, publishDirectory]}

    def ch_samseInput = ch_branchedFlowCellLaneLibraries.samse.map mapToSingleRead
    def ch_memseInput = ch_branchedFlowCellLaneLibraries.memse.map mapToSingleRead
    def ch_sampeInput = ch_branchedFlowCellLaneLibraries.sampe.map mapToPairedEnd
    def ch_mempeInput = ch_branchedFlowCellLaneLibraries.mempe.map mapToPairedEnd

    // Read Length < 75
    // Single Read
    BWA_SAMSE(ch_samseInput, ch_referenceGenome)
    // Paired End
    BWA_SAMPE(ch_sampeInput, ch_referenceGenome)
    
    // Read Length >= 75
    // Single Read
    BWA_MEM_SE(ch_memseInput, ch_referenceGenome, ch_bwaMemOptions)
    // Paired End
    BWA_MEM_PE(ch_mempeInput, ch_referenceGenome, ch_bwaMemOptions)

    def ch_bwaSamOut = Channel.empty()
    ch_bwaSamOut = ch_bwaSamOut.mix(BWA_SAMSE.out.samse)
    ch_bwaSamOut = ch_bwaSamOut.mix(BWA_SAMPE.out.sampe)
    PICARD_CLEAN_SAM(ch_bwaSamOut)


    ch_mappedBams = BWA_MEM_PE.out.mappedBam
    ch_mappedBams = ch_mappedBams.mix(BWA_MEM_SE.out.mappedBam)
    ch_mappedBams = ch_mappedBams.mix(PICARD_CLEAN_SAM.out.mappedBam)

    emit:
        mappedBams = ch_mappedBams
}