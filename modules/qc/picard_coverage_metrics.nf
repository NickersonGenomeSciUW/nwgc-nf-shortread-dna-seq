process PICARD_COVERAGE_METRICS {

    tag "PICARD_COVERAGE_METRICS_${filePrefixString}${partOfSequencingTargetOutput}_${userId}"

    publishDir "${publishDirectory}", mode: 'link', pattern: "${filePrefixString}.BASEQ${baseQuality}.MAPQ${mappingQuality}${partOfSequencingTargetOutput}.picard.coverage.txt"
 
    input:
        tuple path(bam), path(bai), val(sampleId), val(filePrefix), val(userId), val(publishDirectory), val(flowcell), val(lane), val(library)
        tuple val(isGRC38), val(referenceGenome)
        each baseQuality
        each mappingQuality
        each path(intervalsList)

    output:
        tuple val(filePrefix), path("${filePrefixString}.BASEQ${baseQuality}.MAPQ${mappingQuality}${partOfSequencingTargetOutput}.picard.coverage.txt"), emit: metricsFile
        path "versions.yaml", emit: versions

    script:

        // Scrape the chromosome from the intervals list path if it exists.
        partOfSequencingTargetOutput = (intervalsList =~ "(\\.ch.*)?\\.intervals\\.list")[0][1]
        if (partOfSequencingTargetOutput == null) {
            partOfSequencingTargetOutput = ""
        }

        filePrefixString = ""
        if (filePrefix != null) {
            filePrefixString = filePrefix
        }
        else {
            filePrefixString = "${sampleId}"
        }

        """
        mkdir -p ${publishDirectory}

        java \
            -XX:InitialRAMPercentage=80 \
            -XX:MaxRAMPercentage=85 \
            -jar \$PICARD_DIR/picard.jar \
            CollectWgsMetrics \
            --INPUT $bam \
            --REFERENCE_SEQUENCE ${referenceGenome} \
            --VALIDATION_STRINGENCY SILENT \
            --MINIMUM_BASE_QUALITY $baseQuality \
            --MINIMUM_MAPPING_QUALITY $mappingQuality \
            --INTERVALS $intervalsList \
            --COVERAGE_CAP 300000 \
            --OUTPUT ${filePrefixString}.BASEQ${baseQuality}.MAPQ${mappingQuality}${partOfSequencingTargetOutput}.picard.coverage.txt

        cat <<-END_VERSIONS > versions.yaml
        '${task.process}':
            java: \$(java -version 2>&1 | grep version | awk '{print \$3}' | tr -d '"''')
            picard: \$(java -jar \$PICARD_DIR/picard.jar CollectRawWgsMetrics --version 2>&1 | awk '{split(\$0,a,":"); print a[2]}')
        END_VERSIONS

        """

}
