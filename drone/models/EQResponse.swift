//
//  EQResponse.swift
//  drone
//
//  Computes the summed magnitude response (in dB) of an EQSettings for display
//  in the curve. Uses standard RBJ biquad transfer-function magnitudes
//  evaluated at a given frequency, assuming a 44.1 kHz reference rate. This is
//  for visualisation only; the actual DSP is done by AUNBandEQ.
//

import Foundation

enum EQResponse {
    /// Reference sample rate used for the display math. Exact rate barely
    /// affects the shown curve across 20 Hz–20 kHz.
    private static let sampleRate = 44_100.0

    /// Summed response (dB) of all enabled bands + preamp at `frequency` Hz.
    /// Returns 0 when the EQ is disabled.
    static func magnitude(of settings: EQSettings, atFrequency frequency: Double) -> Double {
        guard settings.enabled else { return 0 }
        var total = settings.preamp
        for band in settings.bands where band.enabled {
            total += bandMagnitude(band, atFrequency: frequency)
        }
        return total
    }

    /// Magnitude (dB) contributed by a single band at `frequency`.
    private static func bandMagnitude(_ band: EQBand, atFrequency frequency: Double) -> Double {
        let f0 = band.frequency
        let gainDB = band.gain

        // Convert the AUNBandEQ "bandwidth in octaves" to a biquad Q.
        let bw = max(0.05, band.bandwidth)
        let q = bandwidthToQ(bw)

        let w0 = 2 * Double.pi * f0 / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = sinw0 / (2 * q)
        let a = pow(10, gainDB / 40) // amplitude for shelving/peaking

        // Biquad coefficients (RBJ cookbook) per filter type.
        var b0 = 1.0, b1 = 0.0, b2 = 0.0
        var a0 = 1.0, a1 = 0.0, a2 = 0.0

        switch band.filterType {
        case .parametric:
            b0 = 1 + alpha * a
            b1 = -2 * cosw0
            b2 = 1 - alpha * a
            a0 = 1 + alpha / a
            a1 = -2 * cosw0
            a2 = 1 - alpha / a

        case .lowShelf, .resonantLowShelf:
            let sqrtA = sqrt(a)
            b0 = a * ((a + 1) - (a - 1) * cosw0 + 2 * sqrtA * alpha)
            b1 = 2 * a * ((a - 1) - (a + 1) * cosw0)
            b2 = a * ((a + 1) - (a - 1) * cosw0 - 2 * sqrtA * alpha)
            a0 = (a + 1) + (a - 1) * cosw0 + 2 * sqrtA * alpha
            a1 = -2 * ((a - 1) + (a + 1) * cosw0)
            a2 = (a + 1) + (a - 1) * cosw0 - 2 * sqrtA * alpha

        case .highShelf, .resonantHighShelf:
            let sqrtA = sqrt(a)
            b0 = a * ((a + 1) + (a - 1) * cosw0 + 2 * sqrtA * alpha)
            b1 = -2 * a * ((a - 1) + (a + 1) * cosw0)
            b2 = a * ((a + 1) + (a - 1) * cosw0 - 2 * sqrtA * alpha)
            a0 = (a + 1) - (a - 1) * cosw0 + 2 * sqrtA * alpha
            a1 = 2 * ((a - 1) - (a + 1) * cosw0)
            a2 = (a + 1) - (a - 1) * cosw0 - 2 * sqrtA * alpha

        case .resonantLowPass:
            b0 = (1 - cosw0) / 2
            b1 = 1 - cosw0
            b2 = (1 - cosw0) / 2
            a0 = 1 + alpha
            a1 = -2 * cosw0
            a2 = 1 - alpha

        case .resonantHighPass:
            b0 = (1 + cosw0) / 2
            b1 = -(1 + cosw0)
            b2 = (1 + cosw0) / 2
            a0 = 1 + alpha
            a1 = -2 * cosw0
            a2 = 1 - alpha

        case .bandPass:
            b0 = alpha
            b1 = 0
            b2 = -alpha
            a0 = 1 + alpha
            a1 = -2 * cosw0
            a2 = 1 - alpha

        case .bandStop:
            b0 = 1
            b1 = -2 * cosw0
            b2 = 1
            a0 = 1 + alpha
            a1 = -2 * cosw0
            a2 = 1 - alpha
        }

        return biquadMagnitudeDB(
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0,
            atFrequency: frequency
        )
    }

    /// |H(e^jw)| in dB for a normalised biquad, evaluated at `frequency`.
    private static func biquadMagnitudeDB(
        b0: Double, b1: Double, b2: Double,
        a1: Double, a2: Double,
        atFrequency frequency: Double
    ) -> Double {
        let w = 2 * Double.pi * frequency / sampleRate
        let cosw = cos(w), sinw = sin(w)
        let cos2w = cos(2 * w), sin2w = sin(2 * w)

        // Numerator: b0 + b1 e^-jw + b2 e^-2jw
        let numRe = b0 + b1 * cosw + b2 * cos2w
        let numIm = -(b1 * sinw + b2 * sin2w)
        // Denominator: 1 + a1 e^-jw + a2 e^-2jw
        let denRe = 1 + a1 * cosw + a2 * cos2w
        let denIm = -(a1 * sinw + a2 * sin2w)

        let numMag = sqrt(numRe * numRe + numIm * numIm)
        let denMag = sqrt(denRe * denRe + denIm * denIm)
        guard denMag > 1e-12, numMag > 1e-12 else { return 0 }
        return 20 * log10(numMag / denMag)
    }

    /// Converts a bandwidth in octaves to a biquad Q (standard RBJ relation).
    private static func bandwidthToQ(_ bandwidthOctaves: Double) -> Double {
        let bw = max(0.05, bandwidthOctaves)
        let x = (log(2.0) / 2.0) * bw
        let sinhx = (exp(x) - exp(-x)) / 2
        // Q = 1 / (2 sinh( (ln2/2) * BW )) evaluated with w0≈1 approximation.
        return 1.0 / (2.0 * max(1e-6, sinhx))
    }
}
