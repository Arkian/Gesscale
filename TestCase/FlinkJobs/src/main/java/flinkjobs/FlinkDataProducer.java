package flinkjobs;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import utils.TaxiRide;
import utils.TaxiRideSchema;
import utils.TaxiRideSource;

import java.util.Properties;

/**
 * This job.jar read rides from dataset, creates a Flink source from it, and write records to a sink which is KafKaProducer
 * The rate of data is set here with Speed Factor
 */

public class FlinkDataProducer {

    //private static final String BROKER = "localhost:9092";
   // private static final String TOPIC = "rides";


    public static void main(String[] args) throws Exception {

        ParameterTool params = ParameterTool.fromArgs(args);
        final String input  = params.has("input") ? params.get("input") : "Rides201305-2days.gz";
        final int servingSpeedFactor  = params.has("speed") ? params.getInt("speed") : 30;
        final int maxEventDelay = 0;       // events could be out of order by max this value (seconds)
        final String BROKER  = params.has("broker") ? params.get("broker") : "localhost:9092";
        final String TOPIC  = params.has("topic") ? params.get("topic") : "rides";

        Properties Properties = new Properties();
        Properties.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, BROKER);
        Properties.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        Properties.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);


        DataStream<TaxiRide> rides = env.addSource(new TaxiRideSource(input, maxEventDelay, servingSpeedFactor)).setParallelism(1).name("Source").uid("Source");

        rides.addSink(new FlinkKafkaProducer<TaxiRide>(BROKER, TOPIC, new TaxiRideSchema())).setParallelism(1).name("Sink1").uid("Sink1");
        rides.addSink(new FlinkKafkaProducer<TaxiRide>(BROKER, TOPIC, new TaxiRideSchema())).setParallelism(1).name("iSink2").uid("iSink2");
        rides.addSink(new FlinkKafkaProducer<TaxiRide>(BROKER, TOPIC, new TaxiRideSchema())).setParallelism(1).name("iSink3").uid("iSink3");

        env.execute("FlinkKafkaProducer");


        /*
        TaxiRideSchema schema;
        schema = new SerializationSchema(rides);

        FlinkKafkaProducer<String> myProducer = new FlinkKafkaProducer<>(TOPIC, new TaxiRideSchema(), Properties, FlinkKafkaProducer.Semantic.EXACTLY_ONCE));
        rides.addSink(myProducer);
*/
/*
        TaxiRideSource RideSource = new TaxiRideSource(input, maxEventDelay, servingSpeedFactor);

        while (counter <= 1000000) {
            TaxiRide RideRecord = RideSource.run();
            ProducerRecord<String, TaxiRide> ridesRecords = new ProducerRecord<>(TOPIC, rides);
            producer.send(ridesRecords);
            counter++;
        }
*/


        /*
         int counter = 0;
        KafkaProducer<String, String> producer = new KafkaProducer<>(Properties);

        while (counter <= 1000000) {
            String msg = "Message"+counter;
            ProducerRecord<String, String> record = new ProducerRecord<>(TOPIC, msg);
            producer.send(record);
            counter++;
        }*/

    }



}


