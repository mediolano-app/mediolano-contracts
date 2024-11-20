import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Coins, TrendingUp, Award, Gift, Zap, Shield, Rocket, Star, Clock, CheckCircle2, Flag, ArrowRight, ScrollText, LayoutGrid } from 'lucide-react'

// Mock data
const mockRewards = [
  { id: 1, type: 'Patent Registration', amount: 500, date: '2023-11-15' },
  { id: 2, type: 'Licensing Deal', amount: 1000, date: '2023-11-10' },
  { id: 3, type: 'Community Contribution', amount: 250, date: '2023-11-05' },
  { id: 4, type: 'Trademark Registration', amount: 300, date: '2023-10-30' },
  { id: 5, type: 'IP Valuation', amount: 750, date: '2023-10-25' },
]

const mockNFTs = [
  { id: 1, name: 'Golden Innovator', price: 5000, boost: 20 },
  { id: 2, name: 'Silver Creator', price: 3000, boost: 15 },
  { id: 3, name: 'Bronze Inventor', price: 1500, boost: 10 },
]

const mockRecentActions = [
  { id: 1, action: 'Completed Profile', reward: 100, date: '2023-11-18' },
  { id: 2, action: 'Referred a Friend', reward: 200, date: '2023-11-17' },
  { id: 3, action: 'Attended Webinar', reward: 50, date: '2023-11-16' },
]

export default function UserRewards() {
  const totalRewards = mockRewards.reduce((sum, reward) => sum + reward.amount, 0)

  return (
    <div className="container mx-auto p-4 space-y-8 mt-10 mb-20">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">User Rewards Dashboard</h1>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground'>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Rewards</CardTitle>
            <Coins className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalRewards} Tokens</div>
            <p className="text-xs text-muted-foreground">+20% from last month</p>
          </CardContent>
        </Card>
        <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground'>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Reward Level</CardTitle>
            <Star className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">Gold</div>
            <Progress value={75} className="mt-2" />
          </CardContent>
        </Card>
        <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground'>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">NFTs Owned</CardTitle>
            <Shield className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">32</div>
            <p className="text-xs text-muted-foreground">15% reward boost</p>
          </CardContent>
        </Card>
        <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground'>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Next Milestone</CardTitle>
            <Flag className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">5000 Tokens</div>
            <Progress value={60} className="mt-2" />
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground">
          <CardHeader>
            <CardTitle>Rewards Activity</CardTitle>
            <CardDescription>Your recent rewards and actions</CardDescription>
          </CardHeader>
          <CardContent>
            <ScrollArea className="rounded p-6 h-[400px] pr-4 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground">
              <div className="space-y-8">
                {mockRecentActions.map((action) => (
                  <div key={action.id} className="flex items-center">
                    <div className="space-y-1">
                      <p className="text-sm font-medium leading-none">{action.action}</p>
                      <p className="text-sm text-muted-foreground">{action.date}</p>
                    </div>
                    <div className="ml-auto font-medium">+{action.reward} Tokens</div>
                  </div>
                ))}
                {mockRewards.map((reward) => (
                  <div key={reward.id} className="flex items-center">
                    <div className="space-y-1">
                      <p className="text-sm font-medium leading-none">{reward.type}</p>
                      <p className="text-sm text-muted-foreground">{reward.date}</p>
                    </div>
                    <div className="ml-auto font-medium">+{reward.amount} Tokens</div>
                  </div>
                ))}
              </div>
            </ScrollArea>
          </CardContent>
        </Card>

        <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/75 text-foreground'>
          <CardHeader>
            <CardTitle>Boost Your Rewards</CardTitle>
            <CardDescription>Take these actions to earn more tokens</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4">
            <Button className="w-full justify-start" variant="outline">
              <TrendingUp className="mr-2 h-4 w-4" />
              Register New IP
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <LayoutGrid className="mr-2 h-4 w-4" />
              Marketplace Listing
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <ScrollText className="mr-2 h-4 w-4" />
              License Your IP
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <Award className="mr-2 h-4 w-4" />
              Complete Profile
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <Gift className="mr-2 h-4 w-4" />
              Refer a Friend
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <Clock className="mr-2 h-4 w-4" />
              Attend Webinar
            </Button>
          </CardContent>
        </Card>
      </div>

      <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
        <CardHeader>
          <CardTitle>Features & Benefits</CardTitle>
          <CardDescription>Discover the advantages of our reward system</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div className="flex items-center space-x-4">
            <Zap className="h-8 w-8 text-primary" />
            <div>
              <h3 className="font-semibold">Instant Rewards</h3>
              <p className="text-sm text-muted-foreground">Earn tokens immediately upon IP registration</p>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <TrendingUp className="h-8 w-8 text-primary" />
            <div>
              <h3 className="font-semibold">Tiered Benefits</h3>
              <p className="text-sm text-muted-foreground">Unlock perks as you level up</p>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <Rocket className="h-8 w-8 text-primary" />
            <div>
              <h3 className="font-semibold">Boost Earnings</h3>
              <p className="text-sm text-muted-foreground">Increase rewards with NFTs</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
        <CardHeader>
          <CardTitle>Premium NFTs</CardTitle>
          <CardDescription>Boost your rewards with these exclusive NFTs</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {mockNFTs.map((nft) => (
              <Card key={nft.id}>
                <CardHeader>
                  <CardTitle>{nft.name}</CardTitle>
                  <CardDescription>{nft.boost}% Reward Boost</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{nft.price} Tokens</div>
                </CardContent>
                <CardFooter>
                  <Button className="w-full">
                    Acquire NFT
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </Button>
                </CardFooter>
              </Card>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}