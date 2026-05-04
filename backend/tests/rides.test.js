const request = require('supertest');
const { app } = require('../server');
const dbHandler = require('./setup');
const User = require('../models/User');
const Ride = require('../models/Ride');

beforeAll(async () => await dbHandler.connect());
afterEach(async () => await dbHandler.clearDatabase());
afterAll(async () => await dbHandler.closeDatabase());

describe('Ride System', () => {
  let riderToken, driverToken, driverId, riderId;

  beforeEach(async () => {
    // Create and verify rider
    const rider = new User({
      fullName: 'Test Rider',
      email: 'rider@example.com',
      password: 'password123',
      phoneNumber: '03001111111',
      role: 'rider',
      isEmailVerified: true
    });
    await rider.save();
    riderId = rider._id;
    const riderLogin = await request(app).post('/api/auth/login').send({
      email: 'rider@example.com',
      password: 'password123'
    });
    riderToken = riderLogin.body.token;

    // Create and verify driver
    const driver = new User({
      fullName: 'Test Driver',
      email: 'driver@example.com',
      password: 'password123',
      phoneNumber: '03002222222',
      role: 'driver',
      isEmailVerified: true,
      'kyc.status': 'approved',
      isOnline: true,
      currentLocation: { type: 'Point', coordinates: [67.0011, 24.8607] } // Karachi
    });
    await driver.save();
    driverId = driver._id;
    const driverLogin = await request(app).post('/api/auth/login').send({
      email: 'driver@example.com',
      password: 'password123'
    });
    driverToken = driverLogin.body.token;
  });

  it('should request a ride successfully', async () => {
    const res = await request(app)
      .post('/api/rides/request')
      .set('Authorization', `Bearer ${riderToken}`)
      .send({
        pickupCoordinates: [67.0011, 24.8607],
        pickupAddress: 'Pickup Point',
        dropoffCoordinates: [67.0511, 24.9007],
        dropoffAddress: 'Dropoff Point',
        vehicleTypeId: 'ev_bike'
      });

    expect(res.statusCode).toEqual(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.rideId).toBeDefined();
    
    const ride = await Ride.findById(res.body.data.rideId);
    expect(ride.status).toBe('searching');
  });

  it('should allow driver to accept a ride', async () => {
    // First, request a ride
    const rideRes = await request(app)
      .post('/api/rides/request')
      .set('Authorization', `Bearer ${riderToken}`)
      .send({
        pickupCoordinates: [67.0011, 24.8607],
        dropoffCoordinates: [67.0511, 24.9007]
      });
    
    const rideId = rideRes.body.data.rideId;

    // Driver accepts
    const acceptRes = await request(app)
      .post(`/api/rides/${rideId}/accept`)
      .set('Authorization', `Bearer ${driverToken}`);

    expect(acceptRes.statusCode).toEqual(200);
    expect(acceptRes.body.success).toBe(true);
    
    const ride = await Ride.findById(rideId);
    expect(ride.status).toBe('accepted');
    expect(ride.driver.toString()).toBe(driverId.toString());
  });

  it('should complete a ride lifecycle', async () => {
    // Request and Accept
    const rideRes = await request(app).post('/api/rides/request').set('Authorization', `Bearer ${riderToken}`).send({
      pickupCoordinates: [67.0011, 24.8607],
      dropoffCoordinates: [67.0511, 24.9007]
    });
    const rideId = rideRes.body.data.rideId;
    await request(app).post(`/api/rides/${rideId}/accept`).set('Authorization', `Bearer ${driverToken}`);

    // Arrived
    await request(app)
      .patch(`/api/rides/${rideId}/status`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ newStatus: 'driver_arrived' });

    // In Progress
    await request(app)
      .patch(`/api/rides/${rideId}/status`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ newStatus: 'in_progress' });

    // Completed
    const completeRes = await request(app)
      .patch(`/api/rides/${rideId}/status`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ newStatus: 'completed' });

    expect(completeRes.statusCode).toEqual(200);
    const ride = await Ride.findById(rideId);
    expect(ride.status).toBe('completed');
  });
});
