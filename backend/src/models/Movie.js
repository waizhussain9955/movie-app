const mongoose = require('mongoose');

const serverSchema = new mongoose.Schema({
  id: Number,
  name: String,
  type: { type: String, default: 'embed' },
  quality: String,
  url: String,
  backupUrl: String,
  status: { type: String, default: 'active' },
  priority: Number,
});

const movieSchema = new mongoose.Schema(
  {
    tmdbId: { type: Number, required: true, unique: true, index: true },
    imdbId: { type: String, index: true },
    title: { type: String, required: true },
    overview: String,
    posterUrl: String,
    backdropUrl: String,
    rating: Number,
    year: String,
    mediaType: { type: String, enum: ['movie', 'tv'], default: 'movie' },
    genres: [String],
    runtime: Number,
    servers: [serverSchema],
    views: { type: Number, default: 0 },
    lastFetchedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Movie', movieSchema);

