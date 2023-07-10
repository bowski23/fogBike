package com.bowski.fog_bike;

public class LocationEvent {
    public double latitude;
    public double longitude;
    public int level;

    LocationEvent(double latitude, double longitude, int level) {
        this.latitude = latitude;
        this.longitude = longitude;
        this.level = level;
    }
}
