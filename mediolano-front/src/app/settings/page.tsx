'use client'

import { useState } from 'react'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Bell, Globe, Key, Lock, Settings, Shield, User, Zap, CheckCircle } from 'lucide-react'

// Mockup data
const mockUser = {
  name: 'Alice Johnson',
  email: 'alice@example.com',
  username: 'alice_ip_creator',
  language: 'en',
  twoFactorEnabled: false,
  notificationsEnabled: true,
  ipProtectionLevel: 'standard',
  networkType: 'testnet',
  gasPrice: 'medium',
  autoRegistration: true,
  notificationTypes: {
    ipUpdates: true,
    blockchainEvents: false,
    accountActivity: true
  },
  dataRetention: 180
}

export default function SettingsPage() {
  const [user, setUser] = useState(mockUser)
  const [saveStatus, setSaveStatus] = useState<'idle' | 'saving' | 'saved'>('idle')

  const updateUser = (key: string, value: any) => {
    setUser(prevUser => ({ ...prevUser, [key]: value }))
  }

  const updateNotificationType = (type: string, checked: boolean) => {
    setUser(prevUser => ({
      ...prevUser,
      notificationTypes: {
        ...prevUser.notificationTypes,
        [type]: checked
      }
    }))
  }

  const handleSave = () => {
    setSaveStatus('saving')
    // Simulating an API call
    setTimeout(() => {
      setSaveStatus('saved')
      setTimeout(() => setSaveStatus('idle'), 2000)
    }, 1000)
  }

  return (
    <div className="container mx-auto py-10 px-4 sm:px-6 lg:px-8">
      <h1 className="text-3xl font-bold mb-8">Settings</h1>
      <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3 mb-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <User className="mr-2" /> Account Settings
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="name">Name</Label>
              <Input
                id="name"
                value={user.name}
                onChange={(e) => updateUser('name', e.target.value)}
              />
            </div>
            <div>
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={user.email}
                onChange={(e) => updateUser('email', e.target.value)}
              />
            </div>
            <div>
              <Label htmlFor="username">Username</Label>
              <Input
                id="username"
                value={user.username}
                onChange={(e) => updateUser('username', e.target.value)}
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Shield className="mr-2" /> IP Management
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="ip-protection">IP Protection Level</Label>
              <Select
                value={user.ipProtectionLevel}
                onValueChange={(value) => updateUser('ipProtectionLevel', value)}
              >
                <SelectTrigger id="ip-protection">
                  <SelectValue placeholder="Select Protection Level" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="basic">Basic</SelectItem>
                  <SelectItem value="standard">Standard</SelectItem>
                  <SelectItem value="advanced">Advanced</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center space-x-2">
              <Switch
                id="auto-registration"
                checked={user.autoRegistration}
                onCheckedChange={(checked) => updateUser('autoRegistration', checked)}
              />
              <Label htmlFor="auto-registration">Automatic IP Registration</Label>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Bell className="mr-2" /> Notifications
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center space-x-2">
              <Switch
                id="notifications-enabled"
                checked={user.notificationsEnabled}
                onCheckedChange={(checked) => updateUser('notificationsEnabled', checked)}
              />
              <Label htmlFor="notifications-enabled">Enable Notifications</Label>
            </div>
            <div className="space-y-2">
              <Label>Notification Types</Label>
              <div className="space-y-2">
                <div className="flex items-center space-x-2">
                  <Switch
                    id="ip-updates"
                    checked={user.notificationTypes.ipUpdates}
                    onCheckedChange={(checked) => updateNotificationType('ipUpdates', checked)}
                  />
                  <Label htmlFor="ip-updates">IP Updates</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <Switch
                    id="blockchain-events"
                    checked={user.notificationTypes.blockchainEvents}
                    onCheckedChange={(checked) => updateNotificationType('blockchainEvents', checked)}
                  />
                  <Label htmlFor="blockchain-events">Blockchain Events</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <Switch
                    id="account-activity"
                    checked={user.notificationTypes.accountActivity}
                    onCheckedChange={(checked) => updateNotificationType('accountActivity', checked)}
                  />
                  <Label htmlFor="account-activity">Account Activity</Label>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Lock className="mr-2" /> Security
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center space-x-2">
              <Switch
                id="two-factor"
                checked={user.twoFactorEnabled}
                onCheckedChange={(checked) => updateUser('twoFactorEnabled', checked)}
              />
              <Label htmlFor="two-factor">Two-Factor Authentication</Label>
            </div>
            <div>
              <Label htmlFor="password">Change Password</Label>
              <Input id="password" type="password" placeholder="New Password" className="mb-2" />
              <Input id="password-confirm" type="password" placeholder="Confirm New Password" className="mb-2" />
              <Button className="w-full">Update Password</Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Globe className="mr-2" /> Network Settings
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="network-type">Network Type</Label>
              <Select
                value={user.networkType}
                onValueChange={(value) => updateUser('networkType', value)}
              >
                <SelectTrigger id="network-type">
                  <SelectValue placeholder="Select Network Type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="mainnet">Mainnet</SelectItem>
                  <SelectItem value="testnet">Testnet</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label htmlFor="gas-price">Gas Price Preference</Label>
              <Select
                value={user.gasPrice}
                onValueChange={(value) => updateUser('gasPrice', value)}
              >
                <SelectTrigger id="gas-price">
                  <SelectValue placeholder="Select Gas Price" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="low">Low</SelectItem>
                  <SelectItem value="medium">Medium</SelectItem>
                  <SelectItem value="high">High</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Settings className="mr-2" /> Advanced Settings
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="api-key">API Key</Label>
              <div className="flex space-x-2">
                <Input id="api-key" type="password" value="••••••••••••••••" readOnly className="flex-grow" />
                <Button>Regenerate</Button>
              </div>
            </div>
            <div>
              <Label htmlFor="data-retention">Data Retention (days)</Label>
              <Input
                id="data-retention"
                type="number"
                value={user.dataRetention}
                onChange={(e) => updateUser('dataRetention', parseInt(e.target.value))}
                min={30}
                max={365}
              />
            </div>
            <div>
              <Button variant="destructive" className="w-full">Delete Account</Button>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="flex justify-end mb-8">
        <Button onClick={handleSave} disabled={saveStatus === 'saving'}>
          {saveStatus === 'saving' ? 'Saving...' : saveStatus === 'saved' ? 'Saved!' : 'Save Changes'}
        </Button>
      </div>

      {saveStatus === 'saved' && (
        <Alert className="mb-8">
          <CheckCircle className="h-4 w-4" />
          <AlertTitle>Success</AlertTitle>
          <AlertDescription>Your settings have been saved successfully.</AlertDescription>
        </Alert>
      )}

      <Card className='bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/50 text-foreground'>
        <CardHeader>
          <CardTitle className="flex items-center">
            <Zap className="mr-2" /> Benefits of Decentralized IP Management
          </CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-4">
            <li className="flex items-start">
              <CheckCircle className="mr-2 h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div>
                <strong>Secure Registration:</strong> Immutable blockchain records ensure tamper-proof IP registration.
              </div>
            </li>
            <li className="flex items-start">
              <CheckCircle className="mr-2 h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div>
                <strong>Enhanced Protection:</strong> Decentralized storage and cryptographic techniques provide robust security for your intellectual property.
              </div>
            </li>
            <li className="flex items-start">
              <CheckCircle className="mr-2 h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div>
                <strong>Streamlined Licensing:</strong> Smart contracts automate and enforce licensing agreements, reducing administrative overhead.
              </div>
            </li>
            <li className="flex items-start">
              <CheckCircle className="mr-2 h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div>
                <strong>Efficient Monetization:</strong> Tokenization enables fractional ownership and new revenue streams for your IP assets.
              </div>
            </li>
            <li className="flex items-start">
              <CheckCircle className="mr-2 h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div>
                <strong>Global Commercialization:</strong> Blockchain technology facilitates borderless transactions and broader market access for your intellectual property.
              </div>
            </li>
            <li className="flex items-start">
              <CheckCircle className="mr-2 h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div>
                <strong>Transparent Tracking:</strong> Real-time visibility into IP usage, licensing, and royalty distributions.
              </div>
            </li>
          </ul>
        </CardContent>
      </Card>
    </div>
  )
}