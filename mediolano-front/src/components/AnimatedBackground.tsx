'use client'

import Image from 'next/image'
import { useEffect, useState } from 'react'
import { motion } from "motion/react"

export default function AnimatedBackground() {
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 })

  {/*
  useEffect(() => {
    const updateMousePosition = (e: MouseEvent) => {
      setMousePosition({ x: e.clientX, y: e.clientY })
    }

    window.addEventListener('mousemove', updateMousePosition)

    return () => {
      window.removeEventListener('mousemove', updateMousePosition)
    }
  }, [])*/}

  return (
    <div className="fixed inset-0 z-[-1] overflow-hidden">
      {/* Blurred background image */}
      <Image
        src="/background.jpg"
        alt="Background"
        layout="fill"
        objectFit="cover"
        quality={100}
        className="filter blur-[10px] opacity-10"
        
      />

      {/* Animated gradient overlay */}
      <motion.div
        className="absolute inset-0 opacity-25"
        animate={{
          background: [
            'radial-gradient(circle at 5% 20%, #0000FF, transparent 50%)',
            'radial-gradient(circle at 100% 10%, #0000FF, transparent 50%)',
            'radial-gradient(circle at 20% 100%, #0000FF, transparent 50%)',
            'radial-gradient(circle at 0% 50%, #0000FF, transparent 50%)',
            'radial-gradient(circle at 10% 20%, #0000FF, transparent 50%)',
          ],
        }}
        transition={{
          duration: 50,
          repeat: Infinity,
          repeatType: 'loop',
        }}
      />

      {/* Mouse-following radial gradient 
      <motion.div
        className="absolute inset-0"
        animate={{
          background: `radial-gradient(600px at ${mousePosition.x}px ${mousePosition.y}px, rgba(29, 78, 216, 0.15), transparent 80%)`,
        }}
      />*/}

      {/* Noise texture overlay */}
      <div
        className="absolute inset-0 opacity-90"
        style={{
          backgroundImage: 'url("data:image/svg+xml,%3Csvg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg"%3E%3Cfilter id="noiseFilter"%3E%3CfeTurbulence type="fractalNoise" baseFrequency="0.65" numOctaves="3" stitchTiles="stitch"/%3E%3C/filter%3E%3Crect width="100%" height="100%" filter="url(%23noiseFilter)"/%3E%3C/svg%3E")',
          backgroundRepeat: 'repeat',
          mixBlendMode: 'overlay',
        }}
      />
    </div>
  )
}