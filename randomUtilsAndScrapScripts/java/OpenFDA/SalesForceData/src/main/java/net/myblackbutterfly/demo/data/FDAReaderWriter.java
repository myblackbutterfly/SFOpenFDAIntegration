package net.myblackbutterfly.demo.data;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.dataformat.csv.CsvMapper;
import tools.jackson.dataformat.csv.CsvSchema;

import java.io.File;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import static java.time.format.DateTimeFormatter.*;

public class FDAReaderWriter {

	private static final Logger log = LoggerFactory.getLogger(FDAReaderWriter.class);

	public static final String UNKNOWN = "N/A";

	public record FdaFileRoot(List<CosmeticEvent> results) {
	}

	public record CosmeticEvent(@JsonProperty("initial_received_date") String initialReceivedDate, Patient patient) {
	}

	public record Patient(String age, @JsonProperty("age_unit") String ageUnit) {
	}

	//cvs data model
	@JsonPropertyOrder({ "Event Key", "Event Date", "Age", "count" })
	public record SummaryCsvRow(@JsonProperty("Event Key") String eventKey,
			@JsonProperty("Event Date") String eventDate, @JsonProperty("Age") String ageInYears,
			@JsonProperty("count") long count) {

		// constructor
		public SummaryCsvRow(String eventKey, LocalDate eventDate, String ageInYears, long count) {
			this(eventKey, (eventDate != null) ? eventDate.format(DateTimeFormatter.ISO_LOCAL_DATE) : "", ageInYears,
					count);
		}
	}

	public static void main(String[] args) {

		File inFile = new File(args[0]);
		File outFile = new File(args[1]);

		ObjectMapper jsonMapper = JsonMapper.builder().disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
				.build();

		/*
		 *  ---EXTRACT ---
		*/
		log.info("Reading JSON dataset from {}", inFile.getName());
		FdaFileRoot root = jsonMapper.readValue(inFile, FdaFileRoot.class);
		List<CosmeticEvent> allEvents = (root.results() != null) ? root.results() : List.of();
		log.info("Loaded {} total events from archive", allEvents.size());

		/*
		 *  TRANSFORM
		 */
		List<CosmeticEvent> validDatedEvents = allEvents.stream()
				.filter(e -> e.initialReceivedDate() != null && e.initialReceivedDate().trim().matches("\\d{8}"))
				.toList();

		// Find the newest receipt date in the file 1 year earlier to select a recent sample
		String latestDateStr = validDatedEvents.stream().map(e -> e.initialReceivedDate().trim())
				.max(Comparator.naturalOrder())
				.orElseThrow(() -> new IllegalStateException("No valid dates found in dataset"));

		String oneYearCutoff = LocalDate.parse(latestDateStr, BASIC_ISO_DATE// "YYYYMMDD"7
		).minusYears(1).format(BASIC_ISO_DATE);

		log.info("Filtering to 1-year window: {} through {}", oneYearCutoff, latestDateStr);

		record NormalizedEvent(String receiptDate, String ageInYears) {
			String eventKey() {
				return receiptDate + ":" + ageInYears;
			}
		}

		Map<NormalizedEvent, Long> countsByAge = validDatedEvents.stream()
				.filter(e -> e.initialReceivedDate().trim().compareTo(oneYearCutoff) >= 0)
				.map(e -> new NormalizedEvent(e.initialReceivedDate().trim(), convertAge(e.patient())))
				.collect(Collectors.groupingBy(ne -> ne, Collectors.counting()));

		/*
		 *  --- LOAD (kinda) ---
		 */
		
		List<SummaryCsvRow> csvRows = countsByAge.entrySet().stream().map(entry -> {
			NormalizedEvent ne = entry.getKey();
			long count = entry.getValue();
			// Format receiptDate back to LocalDate if needed by your schema
			LocalDate recDate = LocalDate.parse(ne.receiptDate(), BASIC_ISO_DATE);
			return new SummaryCsvRow(ne.eventKey(), recDate, ne.ageInYears(), count);
		}).toList();

		CsvMapper csvMapper = CsvMapper.builder().build();
		CsvSchema schema = csvMapper.schemaFor(SummaryCsvRow.class).withHeader();
		csvMapper.writer(schema).writeValue(outFile, csvRows);

		long totalIncluded = csvRows.stream().mapToLong(SummaryCsvRow::count).sum();
		log.info("ETL complete. Included {} total events across {} unique keys written to {}", totalIncluded,
				csvRows.size(), outFile.getName());
	}

	private static String convertAge(Patient patient) {

		String ageValueString = UNKNOWN;
		if ((patient != null) && (!(patient.age() == null || patient.age().isBlank()))) {

			try {
				double rawAge = Double.parseDouble(patient.age().trim());
				if (rawAge >= 0) {
					String unit = (patient.ageUnit() == null) ? "year" : patient.ageUnit().trim().toLowerCase();
					double convertedToYears = switch (unit) {
					case "decade", "decades", "decade(s)" -> rawAge * 10.0;
					case "year", "years", "year(s)" -> rawAge;
					case "month", "months", "month(s)" -> rawAge / 12.0;
					case "week", "weeks", "week(s)" -> rawAge / 52.0;
					case "day", "days", "day(s)" -> rawAge / 365.25;
					default -> -1.0;
					};
					ageValueString = String.valueOf(convertedToYears);
				}
			} catch (NumberFormatException e) {
				e.printStackTrace(System.err);
			}
		} else {
			System.err.println((patient == null)?"null":patient.age());
		}

		return ageValueString;
	}
}
