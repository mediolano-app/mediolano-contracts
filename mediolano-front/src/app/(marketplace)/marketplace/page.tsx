import Link from 'next/link'
import Image from 'next/image'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { PaintbrushIcon, BookIcon, FilmIcon, LightbulbIcon, ImageIcon, BuildingIcon, SearchIcon, TrendingUpIcon, SparklesIcon, StarIcon, ChevronRightIcon } from 'lucide-react'

const categories = [
  { name: 'Art', icon: PaintbrushIcon, href: '/category/art', count: '1.2K' },
  { name: 'Publications', icon: BookIcon, href: '/category/publications', count: '856' },
  { name: 'Films', icon: FilmIcon, href: '/category/films', count: '643' },
  { name: 'Patents', icon: LightbulbIcon, href: '/category/patents', count: '1.5K' },
  { name: 'NFTs', icon: ImageIcon, href: '/category/nfts', count: '2.1K' },
  { name: 'Real World Assets', icon: BuildingIcon, href: '/category/rwa', count: '927' },
]

const trendingCollections = [
  {
    id: 1,
    name: "Digital Masterpieces",
    creator: "CryptoArtist",
    volume: "12.5 ETH",
    items: 100,
    floorPrice: "0.5 ETH",
    image: "/background.jpg",
    creatorAvatar: "/placeholder.svg?height=40&width=40",
    verified: true,
  },
  {
    id: 2,
    name: "Scientific Papers Collection",
    creator: "ResearchDAO",
    volume: "25,000 USD",
    items: 50,
    floorPrice: "500 USD",
    image: "/background.jpg",
    creatorAvatar: "/placeholder.svg?height=40&width=40",
    verified: true,
  },
  {
    id: 3,
    name: "Indie Films Bundle",
    creator: "FilmMakers United",
    volume: "8.2 ETH",
    items: 75,
    floorPrice: "0.3 ETH",
    image: "/background.jpg",
    creatorAvatar: "/placeholder.svg?height=40&width=40",
    verified: false,
  },
]

const notableDrops = [
  {
    id: 1,
    title: "Future Tech Patents",
    creator: "TechInnovators",
    date: "Live",
    image: "/background.jpg",
    creatorAvatar: "/placeholder.svg?height=40&width=40",
  },
  {
    id: 2,
    title: "Contemporary Art Collection",
    creator: "ModernArtists",
    date: "Live",
    image: "/background.jpg",
    creatorAvatar: "/placeholder.svg?height=40&width=40",
  },
  {
    id: 3,
    title: "Academic Journal Bundle",
    creator: "ScienceDAO",
    date: "Upcoming",
    image: "/background.jpg",
    creatorAvatar: "/placeholder.svg?height=40&width=40",
  },
]

const topCreators = [
  {
    id: 1,
    name: "CryptoArtist",
    volume: "120.5 ETH",
    avatar: "/placeholder.svg?height=64&width=64",
    verified: true,
  },
  {
    id: 2,
    name: "ResearchDAO",
    volume: "89.2 ETH",
    avatar: "/placeholder.svg?height=64&width=64",
    verified: true,
  },
  {
    id: 3,
    name: "FilmMakers United",
    volume: "67.8 ETH",
    avatar: "/placeholder.svg?height=64&width=64",
    verified: false,
  },
]

export default function Marketplace() {
  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <section className="relative h-[500px] flex items-center justify-center bg-gradient-to-r from-primary/10 to-secondary/10">
        <div className="container px-4 text-center background-image">
          <h1 className="text-4xl md:text-6xl font-bold mb-6">
            Discover, Trade, and Own Intellectual Property
          </h1>
          <p className="text-xl text-muted-foreground mb-8">
            The world's first marketplace for tokenized intellectual property
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button size="lg">Explore Marketplace</Button>
            <Button size="lg" variant="outline">Start Creating</Button>
          </div>
        </div>
      </section>

      {/* Search and Categories */}
      <section className="container px-4 py-12">
        
        
        <div className="grid items-center justify-items-center p-4 gap-8 sm:p-10]">
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
          {categories.map((category) => (
            <Link key={category.name} href={category.href}>
              <Card className="hover:bg-accent transition-colors">
                <CardContent className="flex flex-col items-center justify-center p-6">
                  <category.icon className="h-8 w-8 mb-2" />
                  <span className="text-sm font-medium">{category.name}</span>
                  <Badge variant="secondary" className="mt-2">{category.count}</Badge>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
          </div>


          <div className="relative max-w-4xl mx-auto bg-card/50 rounded mt-10">
          <SearchIcon className="absolute left-3 top-3 h-5 w-5 text-muted-foreground" />
          <Input 
            type="search" 
            placeholder="Search items, collections, and creators..." 
            className="pl-10 h-12"
          />
        </div>

      </section>

      {/* Trending Collections */}
      <div className="grid items-center justify-items-center p-4 gap-8 sm:p-10]">
      <section className="container px-4 py-12">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h2 className="text-2xl font-bold flex items-center gap-2">
              <TrendingUpIcon className="h-6 w-6" />
              Trending Collections
            </h2>
            <p className="text-muted-foreground">The most popular collections in the last 24 hours</p>
          </div>
          <Button variant="ghost">
            View All <ChevronRightIcon className="ml-2 h-4 w-4" />
          </Button>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {trendingCollections.map((collection) => (
            <Card key={collection.id} className="overflow-hidden">
              <div className="relative aspect-square">
                <Image
                  src={collection.image}
                  alt={collection.name}
                  fill
                  className="object-cover transition-transform hover:scale-105"
                />
              </div>
              <CardContent className="p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Avatar className="h-6 w-6">
                    <AvatarImage src={collection.creatorAvatar} />
                    <AvatarFallback>CC</AvatarFallback>
                  </Avatar>
                  <span className="font-medium">{collection.name}</span>
                  {collection.verified && (
                    <Badge variant="secondary">Verified</Badge>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-muted-foreground">Floor</p>
                    <p className="font-medium">{collection.floorPrice}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">Volume</p>
                    <p className="font-medium">{collection.volume}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>
      </div>

      




      {/* Top Creators */}
      <div className="grid items-center justify-items-center p-4 gap-8 sm:p-10]">
      <section className="container px-4 py-12">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h2 className="text-2xl font-bold flex items-center gap-2">
              <StarIcon className="h-6 w-6" />
              Top Creators
            </h2>
            <p className="text-muted-foreground">The most successful creators on our platform</p>
          </div>
          <Button variant="ghost">
            View All <ChevronRightIcon className="ml-2 h-4 w-4" />
          </Button>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {topCreators.map((creator) => (
            <Card key={creator.id}>
              <CardContent className="flex items-center gap-4 p-4">
                <Avatar className="h-16 w-16">
                  <AvatarImage src={creator.avatar} />
                  <AvatarFallback>CC</AvatarFallback>
                </Avatar>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-semibold">{creator.name}</h3>
                    {creator.verified && (
                      <Badge variant="secondary">Verified</Badge>
                    )}
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Volume: {creator.volume}
                  </p>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>
      </div>




          {/* Notable Drops */}
      <div className="grid items-center justify-items-center p-4 gap-8 sm:p-10]">
      <section className="container px-4 py-12">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h2 className="text-2xl font-bold flex items-center gap-2">
              <SparklesIcon className="h-6 w-6" />
              Notable Drops
            </h2>
            <p className="text-muted-foreground">Don't miss out on the latest drops</p>
          </div>
          <Button variant="ghost">
            View All <ChevronRightIcon className="ml-2 h-4 w-4" />
          </Button>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-20">
          {notableDrops.map((drop) => (
            <Card key={drop.id} className="overflow-hidden">
              <div className="relative aspect-square">
                <Image
                  src={drop.image}
                  alt={drop.title}
                  fill
                  className="object-cover transition-transform hover:scale-105"
                />
              </div>
              <CardContent className="p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Avatar className="h-6 w-6">
                      <AvatarImage src={drop.creatorAvatar} />
                      <AvatarFallback>CC</AvatarFallback>
                    </Avatar>
                    <span className="font-medium">{drop.creator}</span>
                  </div>
                  <Badge variant={drop.date === 'Live' ? 'default' : 'secondary'}>
                    {drop.date}
                  </Badge>
                </div>
                <h3 className="font-semibold">{drop.title}</h3>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>
      </div>





    </div>
  )
}