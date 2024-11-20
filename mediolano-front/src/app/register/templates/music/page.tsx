'use client'

import { useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Music, User, Calendar, Tag, Disc, Users, MapPin, Copyright, Link as LinkIcon } from 'lucide-react'

const mockData = [
  { id: 1, title: 'Harmony in G', artist: 'Alice Wonder', album: 'Classical Wonders', releaseDate: '2023-05-15', genre: 'Classical' },
  { id: 2, title: 'Electric Dreams', artist: 'Neon Nights', album: 'Synthwave Anthology', releaseDate: '2023-04-20', genre: 'Electronic' },
  { id: 3, title: 'Acoustic Sunrise', artist: 'Melody Makers', album: 'Morning Serenity', releaseDate: '2023-05-10', genre: 'Folk' },
]

export default function MusicRegistration() {
  const [formData, setFormData] = useState({
    title: '',
    artist: '',
    album: '',
    releaseDate: '',
    genre: '',
    composer: '',
    band: '',
    recordLabel: '',
    location: '',
    copyright: '',
    terms: '',
    fileLink: '',
    lyrics: '',
  })

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Form submitted:', formData)
    alert('Music registration successful!')
    setFormData({
      title: '',
      artist: '',
      album: '',
      releaseDate: '',
      genre: '',
      composer: '',
      band: '',
      recordLabel: '',
      location: '',
      copyright: '',
      terms: '',
      fileLink: '',
      lyrics: '',
    })
  }

  return (
    <div className="min-h-screen py-10 mb-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <Link href="/register/templates" className="inline-flex items-center text-indigo-600 hover:text-indigo-800 mb-8">
          <ArrowLeft className="h-5 w-5 mr-2" />
          Back to Templates
        </Link>
        <h1 className="text-3xl font-extrabold  mb-8">Music Registration</h1>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="bg-card shadow-md rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-4">Register New Music</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="title" className="block text-sm font-medium text-gray-700">Title</label>
                <input
                  type="text"
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="artist" className="block text-sm font-medium text-gray-700">Artist</label>
                <input
                  type="text"
                  id="artist"
                  name="artist"
                  value={formData.artist}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="album" className="block text-sm font-medium text-gray-700">Album</label>
                <input
                  type="text"
                  id="album"
                  name="album"
                  value={formData.album}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="releaseDate" className="block text-sm font-medium text-gray-700">Release Date</label>
                <input
                  type="date"
                  id="releaseDate"
                  name="releaseDate"
                  value={formData.releaseDate}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="genre" className="block text-sm font-medium text-gray-700">Genre</label>
                <input
                  type="text"
                  id="genre"
                  name="genre"
                  value={formData.genre}
                  onChange={handleChange}
                  required
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="composer" className="block text-sm font-medium text-gray-700">Composer</label>
                <input
                  type="text"
                  id="composer"
                  name="composer"
                  value={formData.composer}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="band" className="block text-sm font-medium text-gray-700">Band</label>
                <input
                  type="text"
                  id="band"
                  name="band"
                  value={formData.band}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="recordLabel" className="block text-sm font-medium text-gray-700">Record Label</label>
                <input
                  type="text"
                  id="recordLabel"
                  name="recordLabel"
                  value={formData.recordLabel}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="location" className="block text-sm font-medium text-gray-700">Recording Location</label>
                <input
                  type="text"
                  id="location"
                  name="location"
                  value={formData.location}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="copyright" className="block text-sm font-medium text-gray-700">Copyright</label>
                <input
                  type="text"
                  id="copyright"
                  name="copyright"
                  value={formData.copyright}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="terms" className="block text-sm font-medium text-gray-700">Terms of Use</label>
                <textarea
                  id="terms"
                  name="terms"
                  value={formData.terms}
                  onChange={handleChange}
                  rows={3}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <div>
                <label htmlFor="fileLink" className="block text-sm font-medium text-gray-700">Link to File</label>
                <input
                  type="url"
                  id="fileLink"
                  name="fileLink"
                  value={formData.fileLink}
                  onChange={handleChange}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
              </div>
              <div>
                <label htmlFor="lyrics" className="block text-sm font-medium text-gray-700">Lyrics</label>
                <textarea
                  id="lyrics"
                  name="lyrics"
                  value={formData.lyrics}
                  onChange={handleChange}
                  rows={4}
                  className="mt-1 block w-full rounded-md  shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                ></textarea>
              </div>
              <button
                type="submit"
                className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Register Music
              </button>
            </form>
          </div>

          <div className="rounded-lg p-6 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
            <h2 className="text-xl font-semibold mb-4">Registered Music</h2>
            <ul className="space-y-4">
              {mockData.map((item) => (
                <li key={item.id} className="border-b pb-4 last:border-b-0 last:pb-0">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center">
                      <Music className="h-5 w-5 text-indigo-500 mr-2" />
                      <span className="font-medium">{item.title}</span>
                    </div>
                    <span className="text-sm text-gray-500">{item.genre}</span>
                  </div>
                  <div className="mt-2 flex items-center text-sm text-gray-500">
                    <User className="h-4 w-4 mr-1" />
                    <span>{item.artist}</span>
                    <Disc className="h-4 w-4 ml-4 mr-1" />
                    <span>{item.album}</span>
                    <Calendar className="h-4 w-4 ml-4 mr-1" />
                    <span>{item.releaseDate}</span>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}