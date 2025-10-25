const express = require('express');
const admin = require('../config/firebase');
const db = admin.firestore();

class Sample{
    async samplefunction(req,res){
        try{
            const {userId,massage} = req.body;

            const sampleRef = db.collection('sample').doc();

            await sampleRef.set({
                userId,
                massage
            })

            res.status(200).send('sample data created');
        }catch(e){
            console.log('error creating samole data',e);
            res.status(500).send('error creating  data');
        }
    }
}

module.exports = new Sample();
