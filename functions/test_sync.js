const { initializeApp } = require('firebase/data-connect');
const { getFirestore, collection, doc, setDoc, deleteDoc } = require('firebase/firestore');

const config = {
  apiKey: "AIzaSyA9XQqj9gNvKzT8vKzT8vKzT8vKzT8vKzT8",
  authDomain: "sushiscout26-a8f5d.firebaseapp.com",
  projectId: "sushiscout26-a8f5d",
  storageBucket: "sushiscout26-a8f5d.appspot.com",
  messagingSenderId: "563584335869",
  appId: "1:563584335869:web:abc123"
};

// This won't work without proper credentials
console.log("Please test manually in Firebase Console");
