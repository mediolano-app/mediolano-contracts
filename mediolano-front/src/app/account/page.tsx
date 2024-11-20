'use client'

import { useState } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Switch } from "@/components/ui/switch"
import { Slider } from "@/components/ui/slider"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Book, Briefcase, Copyright, DollarSign, Edit, Globe, Key, Lock, Mail, Shield, User, Wallet, RefreshCw, BarChart } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"

import { useConnect, useDisconnect, useAccount } from '@starknet-react/core';


// Mockup data
const mockUser = {
  name: "0x1a2b...3c4d",
  bio: "Decentralized IP enthusiast and blockchain innovator.",
  ipAssets: [
    { id: "0x123...456", name: "Novel Manuscript", type: "Copyright", status: "Registered", tokenId: "1234" },
    { id: "0x789...abc", name: "AI Algorithm", type: "Patent", status: "Pending", tokenId: "5678" },
    { id: "0xdef...012", name: "Logo Design", type: "Trademark", status: "Licensed", tokenId: "9012" },
  ],
  settings: {
    twoFactor: true,
    emailNotifications: true,
    publicProfile: false,
  },
  transactions: [
    { id: "0xtx1", type: "Registration", asset: "Novel Manuscript", date: "2023-05-15", status: "Confirmed" },
    { id: "0xtx2", type: "License", asset: "Logo Design", date: "2023-06-02", status: "Pending" },
    { id: "0xtx3", type: "Royalty", asset: "AI Algorithm", date: "2023-06-10", status: "Confirmed" },
  ],
  walletBalance: 11.5,
}

export default function AccountPage() {

    const { address } = useAccount();

  const [user, setUser] = useState(mockUser)
  const [theme, setTheme] = useState('light')

  const handleSettingChange = (setting: string) => {
    setUser(prevUser => ({
      ...prevUser,
      settings: {
        ...prevUser.settings,
        [setting]: !prevUser.settings[setting as keyof typeof prevUser.settings]
      }
    }))
  }



  return (
    <div className="container mx-auto px-4 py-8">
      <div className="container mx-auto py-10 text-foreground">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">My Account</h1>
          
        </div>
        <div className="grid gap-6">
         
          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>Blockchain Identity</CardTitle>
              <CardDescription>Your decentralized identity and profile</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center space-x-4">
                <Wallet className="w-12 h-12 text-primary" />
                <div>
                  <h2 className="text-2xl font-bold">{address}</h2>
                  <p className="text-muted-foreground">Starknet Address</p>
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="bio">Bio</Label>
                <Textarea id="bio" defaultValue={user.bio} className="resize-none" />
              </div>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>IP Assets</CardTitle>
              <CardDescription>Your registered and pending intellectual properties on the blockchain</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="space-y-4">
                {user.ipAssets.map(asset => (
                  <li key={asset.id} className="flex items-center justify-between">
                    <div className="flex items-center space-x-4">
                      {asset.type === 'Copyright' && <Book className="text-blue-500 dark:text-blue-400" />}
                      {asset.type === 'Patent' && <Key className="text-green-500 dark:text-green-400" />}
                      {asset.type === 'Trademark' && <Copyright className="text-purple-500 dark:text-purple-400" />}
                      <div>
                        <p className="font-medium">{asset.name}</p>
                        <p className="text-sm text-muted-foreground">{asset.type} - Token ID: {asset.tokenId}</p>
                      </div>
                    </div>
                    <Badge variant={asset.status === 'Registered' ? 'default' : 'secondary'}>
                      {asset.status}
                    </Badge>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>Blockchain Transactions</CardTitle>
              <CardDescription>Recent activities related to your IP assets</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Type</TableHead>
                    <TableHead>Asset</TableHead>
                    <TableHead>Date</TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {user.transactions.map((tx) => (
                    <TableRow key={tx.id}>
                      <TableCell>{tx.type}</TableCell>
                      <TableCell>{tx.asset}</TableCell>
                      <TableCell>{tx.date}</TableCell>
                      <TableCell>
                        <Badge variant={tx.status === 'Confirmed' ? 'default' : 'secondary'}>
                          {tx.status}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>Reputation</CardTitle>
              <CardDescription>Your address reputation @ Mediolano</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
            <div className="space-y-2">
                <Label>Reputation:</Label>
                <Slider defaultValue={[20]} max={100} step={1} />
              </div>
              <div className="flex items-center justify-between">
                
                <div>
                  <p className="font-medium">Value</p>
                  <p className="text-2xl font-bold">{user.walletBalance}</p>
                </div>
                <Button variant="outline">
                  <RefreshCw className="w-4 h-4 mr-2" />
                  Refresh
                </Button>
              </div>
              
              <div className="space-y-2">
                <Label>Network</Label>
                <Select defaultValue="mainnet">
                  <SelectTrigger>
                    <SelectValue placeholder="Select network" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="mainnet">Starknet Mainnet</SelectItem>
                    <SelectItem value="sepolia">Sepolia Testnet</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 text-foreground'>
            <CardHeader>
              <CardTitle>Account Settings</CardTitle>
              <CardDescription>Manage your account preferences and security</CardDescription>
            </CardHeader>
            <CardContent>
              <Tabs defaultValue="security">
                <TabsList>
                  <TabsTrigger value="security">Security</TabsTrigger>
                  <TabsTrigger value="notifications">Notifications</TabsTrigger>
                  <TabsTrigger value="privacy">Privacy</TabsTrigger>
                </TabsList>
                <TabsContent value="security" className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <Label>Two-Factor Authentication</Label>
                      <p className="text-sm text-muted-foreground">Add an extra layer of security to your account</p>
                    </div>
                    <Switch
                      checked={user.settings.twoFactor}
                      onCheckedChange={() => handleSettingChange('twoFactor')}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>Backup Phrase</Label>
                    <p className="text-sm text-muted-foreground">Securely store your wallet's recovery phrase</p>
                    <Button variant="outline">View Recovery Phrase</Button>
                  </div>
                </TabsContent>
                <TabsContent value="notifications" className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <Label>Email Notifications</Label>
                      <p className="text-sm text-muted-foreground">Receive updates about your IP assets and account</p>
                    </div>
                    <Switch
                      checked={user.settings.emailNotifications}
                      onCheckedChange={() => handleSettingChange('emailNotifications')}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>Notification Preferences</Label>
                    <Select defaultValue="all">
                      <SelectTrigger>
                        <SelectValue placeholder="Select notification type" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Notifications</SelectItem>
                        <SelectItem value="important">Important Only</SelectItem>
                        <SelectItem value="none">None</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </TabsContent>
                <TabsContent value="privacy" className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <Label>Public Profile</Label>
                      <p className="text-sm text-muted-foreground">Allow others to see your profile and IP portfolio</p>
                    </div>
                    <Switch
                      checked={user.settings.publicProfile}
                      onCheckedChange={() => handleSettingChange('publicProfile')}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>Data Sharing</Label>
                    <p className="text-sm text-muted-foreground">Choose how your data is shared on the blockchain</p>
                    <Select defaultValue="minimal">
                      <SelectTrigger>
                        <SelectValue placeholder="Select data sharing level" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="full">Full Transparency</SelectItem>
                        <SelectItem value="minimal">Minimal Sharing</SelectItem>
                        <SelectItem value="anonymous">Anonymous</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}