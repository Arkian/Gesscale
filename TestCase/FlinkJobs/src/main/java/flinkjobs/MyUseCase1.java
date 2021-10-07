package flinkjobs;

import utils.TaxiRide;
import utils.TaxiRideSource;
import utils.GeoUtils;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple5;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.joda.time.DateTime;

public class MyUseCase1 {
    public static void main(String[] args) throws Exception {

        ParameterTool params = ParameterTool.fromArgs(args);
        //final String input = params.get("input", "Rides201305-2days.gz");
        final String input  = params.has("input") ? params.get("input") : "Rides201305-2days.gz";
        final int servingSpeedFactor  = params.has("speed") ? params.getInt("speed") : 60;

        final int maxEventDelay = 0;       // events could be out of order by max this value (seconds)
        //final int servingSpeedFactor = 60; // events of this value in seconds are served every second
        //For 1 day event (24 hours), if we set it on 24 (24s-->1s), time of the experiment will be 1hour(60min).

        // set up streaming execution environment
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);
        //env.setStreamTimeCharacteristic(TimeCharacteristic.ProcessingTime);
        env.disableOperatorChaining();
        env.enableCheckpointing(10000);
       // env.setStateBackend(new FsStateBackend("s3://state/checkpoints/"));
        
        // start the data generator (Source operator)
        DataStream<TaxiRide> rides = env.addSource(new TaxiRideSource(input, maxEventDelay, servingSpeedFactor)).setParallelism(1).name("iSource").uid("iSource");

        // map each ride to a tuple of (rideID, StartTime, EndTime) (Map Operator)
        DataStream<Tuple5<Long, DateTime, String, Double, Integer>> tuples = rides.map(new MyMap()).name("iMap").uid("iMap");


        // we could, in fact, print out any or all of these streams (Sink Operator)
        tuples.print().setParallelism(1).name("iSink").uid("iSink");

        // run the pipeline
        env.execute("MyUseCase1");
    }




    /* My Map
     * This is an application that find the closest place (among the three) to the location of taxi when it starts the ride.
    */
    public static class MyMap implements MapFunction<TaxiRide, Tuple5<Long, DateTime, String, Double, Integer>> {

        @Override
        public Tuple5<Long, DateTime, String, Double, Integer> map(TaxiRide taxiRide) throws Exception {

            //Checks if a location specified by longitude and latitude values is
            //within the geo boundaries of New York City.
            //        boolean RideinNY = GeoUtils.isInNYC(taxiRide.endLon, taxiRide.endLat);

////////////Adding complexity
    //        for (int i = 0; i < 10; i++) {
    //            //Creating a random longitude&latitude within the NYC area.
    //            Random rand1 = new Random();
    //            Random rand2 = new Random();
    //            float Randomlat = GeoUtils.getRandomNYCLat(rand1);
    //            float Randomlon = GeoUtils.getRandomNYCLon(rand2);
                /*
                 * Maps a location specified by latitude and longitude values to a cell of a
                 * grid covering the area of NYC.
                 * The grid cells are roughly 100 x 100 m and sequentially number from north-west
                 * to south-east starting by zero.
                 */
    //            int RandomCell = GeoUtils.mapToGridCell(Randomlon, Randomlat);
    //            int RideCell = GeoUtils.mapToGridCell(taxiRide.startLon, taxiRide.startLat);
    //            if (RandomCell == RideCell)
    //                System.out.println("YES");
    //            else
    //                System.out.println("NO");
    //        }


////////////Main App
            // -73.7781, 40.6413 		(JFK Airport)
            double JFKLon = -73.7781;
            double JFKLat = 40.6413;

            // Compute distance and direction between Ride start location and random location (specified by lon/lat pairs)
            double JFKdistance = GeoUtils.getEuclideanDistance(taxiRide.startLon, taxiRide.startLat, (float) JFKLon, (float) JFKLat);
             // Returns the angle in degrees between the vector from the start to the destination
             // and the x-axis on which the start is located.
             // The angle describes in which direction the destination is located from the start, i.e.,
             // 0° -> East, 90° -> South, 180° -> West, 270° -> North
            int JFKdirection = GeoUtils.getDirectionAngle((float) JFKLon, (float) JFKLat, taxiRide.startLon, taxiRide.startLat);


            // -73.966500, 40.781200	(Central Park)
            double CPLon = -73.966500;
            double CPLat = 40.781200;
            double CPdistance = GeoUtils.getEuclideanDistance(taxiRide.startLon, taxiRide.startLat, (float) CPLon, (float) CPLat);
            int CPdirection = GeoUtils.getDirectionAngle((float) CPLon, (float) CPLat, taxiRide.startLon, taxiRide.startLat);

            // -74.044500, 40.689200 (Statue of Liberty)
            double SLLon = -74.044500;
            double SLLat = 40.689200;
            double SLdistance = GeoUtils.getEuclideanDistance(taxiRide.startLon, taxiRide.startLat, (float) SLLon, (float) SLLat);
            int SLdirection = GeoUtils.getDirectionAngle((float) SLLon, (float) SLLat, taxiRide.startLon, taxiRide.startLat);


            //Return name, distance and direction of the closest place
            if( JFKdistance < CPdistance && JFKdistance < SLdistance)
                return new Tuple5<Long, DateTime, String, Double, Integer>(taxiRide.rideId, taxiRide.startTime, "JFKAirport", JFKdistance, JFKdirection );
            else if (CPdistance < JFKdistance && CPdistance < SLdistance)
                return new Tuple5<Long, DateTime, String, Double, Integer>(taxiRide.rideId, taxiRide.startTime, "CentralPark", CPdistance, CPdirection );
            else
                return new Tuple5<Long, DateTime, String, Double, Integer>(taxiRide.rideId, taxiRide.startTime, "statueOfLiberty", SLdistance, SLdirection );


        }
    }



}



