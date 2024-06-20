// store.js
import { configureStore } from '@reduxjs/toolkit';
// import * as actionTypes from "_constants__WEBPACK_IMPORTED_MODULE_0__";
import localforage from 'localforage';
import { combineReducers } from 'redux';
import {
  FLUSH,
  PAUSE,
  PERSIST,
  PURGE,
  REGISTER,
  REHYDRATE,
  persistReducer,
  persistStore,
} from 'redux-persist';
import tokenSlice from './slices/tokenSlice';

const combinedReducer = combineReducers({
  tokens: tokenSlice,
});

const rootReducer = (state, action) => {
  return combinedReducer(state, action);
};

const persistConfig = {
  key: 'redux',
  storage: localforage,
};

const persistedReducer = persistReducer(persistConfig, rootReducer);

// Make sure to configure localforage bxefore the Redux store is created
localforage.config({
  driver: localforage.INDEXEDDB, // or localforage.LOCALSTORAGE
  name: 'fhe',
  storeName: 'fhe',
  version: 1.0,
  description: 'fhe store',
});

export const store = configureStore({
  reducer: persistedReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
});

export const persistor = persistStore(store);
