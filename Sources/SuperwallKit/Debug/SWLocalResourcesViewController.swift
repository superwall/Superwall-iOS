//
//  SWLocalResourcesViewController.swift
//  SuperwallKit
//

import UIKit
import AVFoundation

final class SWLocalResourcesViewController: UICollectionViewController {
  private var resources: [(id: String, url: URL)] = []

  init() {
    let layout = UICollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 12
    layout.minimumLineSpacing = 16
    layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    super.init(collectionViewLayout: layout)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Local Resources"
    view.backgroundColor = darkBackgroundColor
    collectionView.backgroundColor = darkBackgroundColor

    collectionView.register(
      LocalResourceCell.self,
      forCellWithReuseIdentifier: LocalResourceCell.reuseId
    )
    collectionView.register(
      EmptyResourcesCell.self,
      forCellWithReuseIdentifier: EmptyResourcesCell.reuseId
    )

    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = lightBackgroundColor
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    navigationController?.navigationBar.standardAppearance = appearance
    navigationController?.navigationBar.scrollEdgeAppearance = appearance

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "Done",
      style: .plain,
      target: self,
      action: #selector(doneTapped)
    )
    navigationItem.rightBarButtonItem?.tintColor = primaryColor

    resources = Superwall.shared.options.localResources
      .sorted { $0.key < $1.key }
      .map { (id: $0.key, url: $0.value) }
  }

  @objc private func doneTapped() {
    dismiss(animated: true)
  }

  // MARK: - Data Source

  override func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return resources.isEmpty ? 1 : resources.count
  }

  override func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    if resources.isEmpty {
      return collectionView.dequeueReusableCell(
        withReuseIdentifier: EmptyResourcesCell.reuseId,
        for: indexPath
      )
    }

    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: LocalResourceCell.reuseId,
      for: indexPath
    // swiftlint:disable:next force_cast
    ) as! LocalResourceCell
    let resource = resources[indexPath.item]
    cell.configure(id: resource.id, url: resource.url)
    return cell
  }
}

// MARK: - Flow Layout

extension SWLocalResourcesViewController: UICollectionViewDelegateFlowLayout {
  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    if resources.isEmpty {
      return CGSize(width: collectionView.bounds.width - 32, height: 100)
    }
    let width = (collectionView.bounds.width - 44) / 2
    return CGSize(width: width, height: width + 30)
  }
}

// MARK: - Empty State Cell

private final class EmptyResourcesCell: UICollectionViewCell {
  static let reuseId = "EmptyResourcesCell"

  private let label: UILabel = {
    let label = UILabel()
    label.text = "No local resources registered.\nSet SuperwallOptions.localResources before calling configure()."
    label.textColor = UIColor.white.withAlphaComponent(0.5)
    label.font = .systemFont(ofSize: 14)
    label.numberOfLines = 0
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Resource Cell

private final class LocalResourceCell: UICollectionViewCell {
  static let reuseId = "LocalResourceCell"

  private let idLabel: UILabel = {
    let label = UILabel()
    label.font = .boldSystemFont(ofSize: 13)
    label.textColor = primaryColor
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let previewContainer: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.white.withAlphaComponent(0.05)
    view.layer.cornerRadius = 8
    view.layer.cornerCurve = .continuous
    view.clipsToBounds = true
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private let errorLabel: UILabel = {
    let label = UILabel()
    label.font = .systemFont(ofSize: 12)
    label.textColor = UIColor.red.withAlphaComponent(0.7)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private let spinner: UIActivityIndicatorView = {
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.color = .white
    spinner.hidesWhenStopped = true
    spinner.translatesAutoresizingMaskIntoConstraints = false
    return spinner
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)

    contentView.addSubview(idLabel)
    contentView.addSubview(previewContainer)
    previewContainer.addSubview(imageView)
    previewContainer.addSubview(spinner)
    previewContainer.addSubview(errorLabel)

    NSLayoutConstraint.activate([
      idLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
      idLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      idLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      idLabel.heightAnchor.constraint(equalToConstant: 22),

      previewContainer.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 4),
      previewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      previewContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      previewContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

      imageView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 4),
      imageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 4),
      imageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -4),
      imageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -4),

      spinner.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),

      errorLabel.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
      errorLabel.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    imageView.image = nil
    imageView.isHidden = false
    errorLabel.text = nil
    spinner.stopAnimating()
  }

  func configure(id: String, url: URL) {
    let ext = url.pathExtension.lowercased()
    idLabel.text = ext.isEmpty ? id : "\(id).\(ext)"
    spinner.startAnimating()

    switch ext {
    case "jpg", "jpeg", "png", "gif", "webp", "svg", "heic":
      loadImage(from: url)
    case "mp4", "m4v", "mov", "webm":
      loadVideoThumbnail(from: url)
    default:
      spinner.stopAnimating()
      if !FileManager.default.fileExists(atPath: url.path) {
        showErrorText("File not found")
      }
    }
  }

  private func loadImage(from url: URL) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard
        let data = try? Data(contentsOf: url),
        let image = UIImage(data: data)
      else {
        DispatchQueue.main.async {
          self?.showErrorText("Image not found")
        }
        return
      }
      DispatchQueue.main.async {
        self?.spinner.stopAnimating()
        self?.imageView.image = image
      }
    }
  }

  private func loadVideoThumbnail(from url: URL) {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let time = CMTime(seconds: 0, preferredTimescale: 600)

    #if os(visionOS)
    Task { [weak self] in
      guard let (cgImage, _) = try? await generator.image(at: time) else {
        await MainActor.run { self?.showErrorText("Video not found") }
        return
      }
      let thumbnail = UIImage(cgImage: cgImage)
      await MainActor.run {
        self?.spinner.stopAnimating()
        self?.imageView.image = thumbnail
      }
    }
    #else
    if #available(iOS 16.0, *) {
      Task { [weak self] in
        guard let (cgImage, _) = try? await generator.image(at: time) else {
          await MainActor.run { self?.showErrorText("Video not found") }
          return
        }
        let thumbnail = UIImage(cgImage: cgImage)
        await MainActor.run {
          self?.spinner.stopAnimating()
          self?.imageView.image = thumbnail
        }
      }
    } else {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
          DispatchQueue.main.async { self?.showErrorText("Video not found") }
          return
        }
        let thumbnail = UIImage(cgImage: cgImage)
        DispatchQueue.main.async {
          self?.spinner.stopAnimating()
          self?.imageView.image = thumbnail
        }
      }
    }
    #endif
  }

  private func showErrorText(_ text: String) {
    spinner.stopAnimating()
    errorLabel.text = text
  }
}
